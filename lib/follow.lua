local new_mode = new_mode
local debug = debug
local add_binds = add_binds
local print = print
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
window.luakit_follow = (function () {
    // Secret squirrel data/functions
    var priv = { api: window.luakit_follow_api };
    delete window.luakit_follow_api;

    // Launch callback function asynchronously
    function async(func) { return setTimeout(func, 1); };

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

    function Hint(element, overlay, scroll_x, scroll_y) {
        this.element = element;
        this.tag = element.tagName.toLowerCase();

        var rect0 = element.getClientRects()[0];

        // Create hint overlay
        var o = document.createElement("span");
        o.className = "follow_hint_overlay follow_hint_overlay_" + this.tag;
        var style = o.style;
        style.left = (scroll_x + rect0.left) + "px";
        style.top = (scroll_y + rect0.top) + "px";
        style.width = ( rect0.right - rect0.left ) + "px";
        style.height = ( rect0.bottom - rect0.top ) + "px";

        // Create hint span
        var l = document.createElement("span");
        l.className = "follow_hint_label follow_hint_label_" + this.tag;
        var style = l.style;
        style.left = Math.max(scroll_x, (scroll_x + rect0.left - 5)) + "px";
        style.top = Math.max(scroll_y, (scroll_y + rect0.top - 5)) + "px";
        l.innerHTML = "asdf";

        this.overlay = o;
        this.label = l;

        overlay.appendChild(o);
        overlay.appendChild(l);
    }

    function make_hints(elements, overlay) {
        var hints = [];

        var scroll_x = document.defaultView.scrollX,
            scroll_y = document.defaultView.scrollY;

        var len = elements.length;
        for (var i = 0; i < len; i++)
            hints.push(new Hint(elements[i], overlay, scroll_x, scroll_y));

        return hints;
    }

    function eval_selector(selector) {
        // Get viewport dimensions
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

            elements.push(e);
        }

        // Sort left to right
        elements.sort(function (a, b) {
            return a.getClientRects()[0].left - b.getClientRects()[0].left;
        });
        // Sort top to bottom
        elements.sort(function (a, b) {
            return a.getClientRects()[0].top - b.getClientRects()[0].top;
        });

        return elements;
    }

    function cleanup() {
        unlink(priv.stylesheet);
        delete priv.stylesheet;

        unlink(priv.overlay);
        delete priv.overlay;

        delete priv.hints;
    }

    function init() {
        var api = priv.api;

        // Get follow mode options
        var mode = api("mode-options");

        // Find all matching elements for given follow mode selector
        var elements = eval_selector(mode.selector);

        if (elements.length === 0)
            return 0;

        priv.stylesheet = create_stylesheet(
            "luakit_follow_stylesheet", mode.css);

        priv.overlay = create_overlay("luakit_follow_overlay");

        priv.hints = make_hints(elements, priv.overlay);

        priv.overlay.style.display = "inline";

        return priv.hints.length;
    }

    return {
        init: init,
        cleanup: cleanup
    };
})();
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

    return "ready"
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

local function show_labels(state, count)
    local labels, i = gen_labels(count), 1
    local frames = state.frames
    for _, f in ipairs(frames) do
        local d = frames[f]
        print(f, table.concat(labels, ",", i, i + d.count - 1))
        i = i + d.count
    end
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
        local view, data = w.view, {}
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

            if count == "ready" then
                view:register_function("luakit_follow_api", function (...)
                    return api(w, f, ...)
                end, f)

                count, err = view:eval_js(follow_js, opts)
                assert(not err, err)
            end

            if type(count) == "number" and count > 0 then
                frames[f] = { count = count }
                table.insert(frames, f)
                total_count = total_count + count
            end
        end

        if #frames == 0 then
            w:set_mode()
            return
        end

        if total_count == 0 then
            w:notify("No matches...")
            w:set_mode()
            return
        end

        print("TOTAL TIME", capi.luakit.time() - state.time)
    end,

    leave = function (w)
        local state = w.follow_state
        local view = state.view
        for _, f in ipairs(state.frames) do
            view:eval_js(cleanup_js, { frame = f })
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
