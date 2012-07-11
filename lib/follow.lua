local new_mode = new_mode
local debug = debug
local add_binds = add_binds
local print = print
local math = math
local lousy = require "lousy"
local ipairs = ipairs
local pairs = pairs
local string = string
local select = select
local unpack = unpack
local tostring = tostring
local table = table
local assert = assert
local type = type
local capi = {
    luakit = luakit
}

module("follow")

follow_js = [=[
window.luakit_follow = (function (window, document) {
    // Secret squirrel data
    var priv = {};

    // Prevent other scripts using the luakit_follow_api function (I hope)
    var api = window.luakit_follow_api;
    delete window.luakit_follow_api;

    // Unlink element from DOM (and return it)
    function unlink(element) {
        if (typeof element === "string")
            element = document.getElementById(element);

        if (element) {
            element.parentNode.removeChild(element);
            return element;
        }
    }

    function create_stylesheet(id, rules) {
        var head = document.getElementsByTagName('head')[0],
            style = document.createElement('style'),
            rules = document.createTextNode(rules);
        style.id = id;
        style.type = 'text/css';
        style.appendChild(rules);
        head.appendChild(style);
        return style;
    }

    function create_overlay(id) {
        var overlay = document.createElement("div");
        document.body.appendChild(overlay);
        overlay.id = id;
        return overlay;
    }

    function Hint(arr, label) {
        this.element = arr[0];
        this.left = arr[1];
        this.top = arr[2];
        this.right = arr[3];
        this.bottom = arr[4];
        this.label = label;
        this.tag = this.element.tagName.toLowerCase();
        if (this.tag === "input" || this.tag === "select")
            this.text = this.element.value;
        else
            this.text = this.element.textContent;
    }

    Hint.prototype.make_html = function (scroll_x, scroll_y) {
        // Check if already generated
        if (this.html)
            return this.html;

        var left = scroll_x + this.left, top = scroll_y + this.top;

        this.html = ["<span class='follow_hint_overlay follow_hint_overlay_",
            this.tag, "' style='left:", left, "px; top:", top, "px; width:",
            (this.right - this.left), "px; height:", (this.bottom - this.top),
            "px;'></span><span class='follow_hint_label follow_hint_label_",
            this.tag, "' style='left:", Math.max(scroll_x, left - 10),
            "px; top:", Math.max(scroll_y, top - 10), "px;'>", this.label,
            "</span>"].join("");

        return this.html;
    }

    function eval_selector(selector) {
        var win_h = window.innerHeight,
            win_w = window.innerWidth;

        var elements = [];
        var results = document.querySelectorAll(selector);

        var len = results.length;
        for (var i = 0; i < len; i++) {
            var e = results[i];
            var r = e.getBoundingClientRect();

            // Check if element outside viewport
            if (!r || r.top >  win_h || r.bottom < 0
                || r.left > win_w || r.right < 0
                || !e.getClientRects()[0])
                continue;

            elements.push([e, r.left, r.top, r.right, r.bottom]);
        }

        // Sort elements top to bottom left to right
        elements.sort(function (a, b) { return a[1] - b[1]; });
        elements.sort(function (a, b) { return a[2] - b[2]; });

        return elements;
    }

    function show_hints(hints) {
        var len = hints.length, html = [], overlay = priv.overlay;

        for (var i = 0; i < len; i++)
            html.push(hints[i].html);

        overlay.style.display = "none";
        overlay.innerHTML = html.join("");
        overlay.style.display = "inline";
    }

    function make_hints(elements, labels, overlay) {
        var hints = [], len = elements.length,
            scroll_x = document.defaultView.scrollX,
            scroll_y = document.defaultView.scrollY;

        for (var i = 0; i < len; i++) {
            var hint = new Hint(elements[i], labels[i]);
            hint.make_html(scroll_x, scroll_y);
            hints.push(hint);
        }

        return hints;
    }

    function init() {
        priv.mode = api("mode-options");
        priv.elements = eval_selector(priv.mode.selector);
        return priv.elements.length;
    }

    function show(labels) {
        priv.overlay = create_overlay("luakit_follow_overlay");
        priv.stylesheet = create_stylesheet("luakit_follow_stylesheet",
            priv.mode.css);

        priv.hints = make_hints(priv.elements, labels.split(" "));

        show_hints(priv.hints);
    }

    function cleanup() {
        unlink(priv.stylesheet);
        delete priv.stylesheet;

        unlink(priv.overlay);
        delete priv.overlay;

        delete priv.hints;
    }

    function strneq(a, b, n) {
        return !!(a && b && a.substring(0, n) == b.substring(0, n));
    }

    function filter(pat) {
        var last = priv.last_pat;
        if (last === pat) return;
        var re = new RegExp(pat);

        var hints = last && strneq(last, pat, last.length) ?
            priv.filtered_hints : priv.hints;

        hints = hints.filter(function (hint) {
            return re.test(hint.label) || re.test(hint.text);
        });

        // Save info for next call
        priv.last_pat = pat;
        priv.filtered_hints = hints;

        show_hints(hints);

        return hints.length;
    }

    return {
        init: init,
        cleanup: cleanup,
        show: show,
        filter: filter,
    };
})(window, document);
window.luakit_follow.init();
]=]

cleanup_js = [=[
window.luakit_follow && window.luakit_follow.cleanup()
]=]

init_js = [=[
(function () {
    // Return if this frames document is not ready
    if (!(document.body && /interactive|loaded|complete/.test(
        document.readyState))) return;

    if (window.luakit_follow)
        return window.luakit_follow.init();

    return "first-run"
})()
]=]

function gen_labels(count)
    local ret = {}
    for i=1, count do
        ret[i] = tostring(i)
    end
    return ret
end

local function count_matches(frames)
    local n = 0
    for _, d in pairs(frames) do n = n + d.count end
    return n
end

-- Calculates the minimum number of characters needed in a hint given a
-- charset of a certain length (I.e. the base)
local function max_hint_len(size, base)
    local floor, len = math.floor, 0
    while size > 0 do size, len = floor(size / base), len + 1 end
    return len
end

--- Style that uses a given set of characters for the hint labels and
-- does not perform text matching against the page elements.
--
-- @param charset A string of characters to use for the hint labels.
function charset(charset, size)
    local floor, sub = math.floor, string.sub
    local insert, concat = table.insert, table.concat

    local base = #charset
    local digits = max_hint_len(size, base)
    local labels, blanks = {}, {}
    for n = 1, digits do
        insert(blanks, sub(charset, 1, 1))
    end
    for n = 1, size do
        local t, d = {}
        repeat
            d, n = (n % base) + 1, floor(n / base)
            insert(t, 1, sub(charset, d, d))
        until n == 0
        insert(labels, concat(blanks, "", #t + 1) .. concat(t, ""))
    end
    return labels
end

local function api(w, frame, action, ...)
    local state = w.follow_state
    --print("API", frame, action, unpack({...}))

    if action == "mode-options" then
        return { selector = state.mode.selector, css = state.mode.css }
    end
end

new_mode("follow", {
    enter = function (w)
        local view = w.view
        local all_frames, frames = view.frames, {}

        local mode = w.follow_mode
        local state = { mode = mode, view = view, frames = frames,
            ready_count = 0, time = capi.luakit.time() }
        w.follow_state = state

        local total_count = 0
        for _, f in ipairs(all_frames) do
            local opts = { frame = f }
            local count, err = view:eval_js(init_js, opts)
            assert(not err, err)

            if count == "first-run" then
                view:register_function("luakit_follow_api", function (...)
                    return api(w, f, ...)
                end, f)

                count, err = view:eval_js(follow_js, opts)
                assert(not err, err)
            end

            if type(count) == "number" and count > 0 then
                table.insert(frames, { frame = f, count = count })
                total_count = total_count + count
            end
        end

        if #frames == 0 then
            print("No frames")
            w:set_mode()
            return
        end

        if total_count == 0 then
            print("no matches")
            w:set_mode()
            return
        end

        -- Make all the labels
        local labels = charset("0123456789", total_count)

        -- Give each frame its hint labels
        local i = 1
        for _, d in ipairs(frames) do
            view:eval_js(string.format("window.luakit_follow.show(%q)",
                table.concat(labels, " ", i, i + d.count - 1)),
                { frame = d.frame, no_return = true })
            i = i + d.count
        end

        print("HINT CREATION TIME", capi.luakit.time() - state.time)

        w:set_prompt("Follow:")
        w:set_input("")
    end,

    changed = function (w, text)
        local a = capi.luakit.time()
        local state = w.follow_state or {}
        local frames, view = state.frames, state.view
        local active_count = 0

        for _, d in ipairs(frames) do
            local filter = string.format("luakit_follow.filter(%q)", text)
            local count, err = view:eval_js(filter, { frame = d.frame })
            if type(count) == "number" then
                active_count = active_count + count
            end
        end
        print("FILTER TIME", capi.luakit.time() - a, "ACTIVE HINTS", active_count)
    end,

    leave = function (w)
        local state = w.follow_state
        local view = state.view
        for _, d in ipairs(state.frames) do
            view:eval_js(cleanup_js, { frame = d.frame })
        end
    end,
})

local buf = lousy.bind.buf
add_binds("normal", {
    buf("^f$", function (w, b, m)
        w.follow_mode = {
            selector = 'a',
            css = [===[
                #luakit_follow_overlay {
                    display: none;
                }

                #luakit_follow_overlay .follow_hint_overlay {
                    background-color: #ffff99;
                    border: 1px dotted #000;
                    opacity: 0.3;
                    position: absolute;
                    z-index: 10001;
                }

                #luakit_follow_overlay .follow_hint_label {
                    background-color: #000088;
                    border: 1px dashed #000;
                    color: #fff;
                    font: 11px monospace bold;
                    opacity: 0.4;
                    position: absolute;
                    z-index: 10002;
                }

                #luakit_follow_overlay .follow_hint_overlay_body {
                    background-color: #ff0000;
                }
            ]===],
        }
        w:set_mode("follow")
    end),
})
