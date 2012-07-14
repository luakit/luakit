------------------------------------------------------------
-- Link hinting for luakit                                --
-- © 2010-2012 Mason Larobina  <mason.larobina@gmail.com> --
-- © 2010-2011 Fabian Streitel <karottenreibe@gmail.com>  --
------------------------------------------------------------

-- Get Lua environ
local print = print
local pairs, ipairs = pairs, ipairs
local table, string = table, string
local assert, type = assert, type
local floor = math.floor
local rawset, rawget = rawset, rawget

-- Get luakit environ
local lousy = require "lousy"
local new_mode, add_binds = new_mode, add_binds
local window = window
local capi = {
    luakit = luakit
}

module("follow")

follow_js = [=[
window.luakit_follow = (function (window, document) {
    // Follow session state
    var state = {};

    // Secret squirrel data
    var api = window.luakit_follow_api;
    delete window.luakit_follow_api;

    // Unlink element from DOM (and return it)
    function unlink(e) {
        if (typeof e === "string")
            e = document.getElementById(e);

        if (e) {
            e.parentNode.removeChild(e);
            return e;
        }
    }

    function create_stylesheet(id, rules) {
        var style = document.createElement('style');
        style.id = id;
        style.type = 'text/css';
        style.appendChild(document.createTextNode(rules));
        return style;
    }

    function create_overlay(id, html) {
        var overlay = document.createElement("div");
        overlay.id = id;
        overlay.innerHTML = html;
        return overlay;
    }

    var sort_hints_top_left = function (a, b) {
        var dtop = a.top - b.top;
        return dtop !== 0 ? dtop : a.left - b.left;
    }

    function eval_selector_make_hints(selector) {
        var elems = document.querySelectorAll(selector), len = elems.length,
            win_h = window.innerHeight, win_w = window.innerWidth,
            hints = [], i = 0, j = 0, e, r, top, bottom, left, right;

        for (; i < len;) {
            e = elems[i++];
            r = e.getClientRects()[0];

            // Check if element outside viewport
            if (!r || (top  = r.top)  > win_h || (bottom = r.bottom) < 0
                   || (left = r.left) > win_w || (right  = r.right)  < 0)
               continue;

            hints[j++] = { element: e, tag: e.tagName,
                left: left, top: top, bottom: bottom, right: right,
                text: e.value || e.textContent };
        }

        hints.sort(sort_hints_top_left);
        return hints;
    }

    function assign_labels_make_html(hints, labels) {
        var win = document.defaultView,
            scroll_x = win.scrollX, scroll_y = win.scrollY,
            i = 0, len = hints.length, h, tag, label,
            left, top, h_left, h_top, l_left, l_top, html = ""

        for (; i < len; i++) {
            h = hints[i];
            label = labels[i];
            h.label = label;

            tag = h.tag;
            left = h.left;
            top = h.top;

            // hint position offset by window scroll
            h_left = scroll_x + left;
            h_top = scroll_y + top;

            // hint label position offset by -10x -10y
            if ((l_left = h_left - 10) < 0) l_left = scroll_x;
            if ((l_top  = h_top  - 10) < 0) l_top  = scroll_y;

            h.html = "<span class='hint_overlay hint_overlay_"
                + tag + "' style='left:" + h_left + "px; top:" + h_top
                + "px; width:" + (h.right - left) + "px; height:"
                + (h.bottom - top) + "px;'></span>"
                + "<span class='hint_label hint_label_" + tag
                + "' style='left:" + l_left + "px; top:" + l_top + "px;'>"
                + label + "</span>\n";

            html += h.html;
        }

        return html;
    }

    function show_hints(html) {
        if (html === state.last_html)
            return;

        var current_overlay = state.overlay,
            overlay = create_overlay("luakit_follow_overlay", html);

        if (current_overlay)
            document.body.replaceChild(overlay, current_overlay);
        else
            document.body.appendChild(overlay);

        state.last_html = html;
        state.overlay = overlay;
    }

    function init() {
        var mode = api("mode-options"),
            hints = eval_selector_make_hints(mode.selector);
        state.mode = mode;
        state.hints = hints;
        state.filtered_hints = hints;
        return hints.length;
    }

    function unfocus() {
        var f = state.focused;
        if (f) {
            f.element.className = f.orig_class;
            delete state.focused;
        }
    }

    function focus(step) {
        var hints = state.filtered_hints, last = state.focused, i = 0;

        unfocus();

        if (hints.length === 0)
            return "next-frame";

        var labels = document.querySelectorAll("#luakit_follow_overlay .hint_overlay"),
            len = labels.length;

        if (step === "first")
            i = 0

        else if (step === "last")
            i = len - 1;

        // Focus next element
        else if (last)
            i = last.index + step;

        // Move to next frame
        if (i >= len || i < 0)
            return "next-frame";

        e = labels[i];
        state.focused = { element: e, index: i, orig_class: e.className };
        e.className += " hint_selected";

        return i;
    }

    function show(labels) {
        var rules = state.mode.stylesheet,
            labels = labels.split(" "),
            head = document.getElementsByTagName('head')[0],
            style = create_stylesheet("luakit_follow_stylesheet", rules);

        head.appendChild(style);
        state.stylesheet = style;

        show_hints(assign_labels_make_html(state.hints, labels));
    }

    function cleanup() {
        unlink(state.stylesheet);
        unlink(state.overlay);

        // Reset follow state
        state = {};
    }

    function filter(pat) {
        var last = state.last_pat;

        if (last === pat)
            return state.filtered_hints.length;

        var hints = last && pat.substring(0, last.length) === last ?
            state.filtered_hints : state.hints;

        var len = hints.length, i = 0, html = "";

        // Render all hints
        if (pat === "") {
            for (; i < len;)
                html += hints[i++].html;

        // Filter hints by pattern
        } else if (len > 0) {
            var label_re = new RegExp("^" + pat), text_re = new RegExp(pat),
                matches = [], j = 0, h;

            for (; i < len;) {
                h = hints[i++];
                if (label_re.test(h.label) || text_re.test(h.text)) {
                    matches[j++] = h;
                    html += h.html;
                }
            }
            hints = matches;
        }

        // Save info for next call
        state.last_pat = pat;
        state.filtered_hints = hints;

        show_hints(html);

        return hints.length;
    }

    function focused_element() {
        return state.filtered_hints[state.focused.index].element;
    }

    function visible_elements() {
        var hints = state.filtered_hints, elems = [], i = 0;
        for (; i < len;)
            elems[i] = hints[i].element;
        return elems;
    }

    return {
        init: init,
        cleanup: cleanup,
        show: show,
        filter: filter,
        focus: focus,
        unfocus: unfocus,
        focused_element: focused_element,
        visible_elements: visible_elements,
    }
})(window, document);
window.luakit_follow.init();
]=]

init_js = [=[
(function () {
    if (!document.body)
        return;

    if (window.luakit_follow)
        return window.luakit_follow.init();

    return "first-run";
})()
]=]

stylesheet = [===[
#luakit_follow_overlay .hint_overlay {
    background-color: #ffff99;
    border: 1px dotted #000;
    opacity: 0.3;
    position: absolute;
    z-index: 10001;
}

#luakit_follow_overlay .hint_label {
    background-color: #000088;
    border: 1px dashed #000;
    color: #fff;
    font: 11px monospace bold;
    opacity: 0.4;
    position: absolute;
    z-index: 10002;
}

#luakit_follow_overlay .hint_overlay_body {
    background-color: #ff0000;
}

#luakit_follow_overlay .hint_selected {
    background-color: #00ff00 !important;
}
]===]

-- Calculates the minimum number of characters needed in a hint given a
-- charset of a certain length (I.e. the base)
local function max_hint_len(size, base)
    local floor, len = floor, 0
    while size > 0 do size, len = floor(size / base), len + 1 end
    return len
end

local function charset(seq, size)
    local floor, sub, reverse = floor, string.sub, string.reverse
    local insert, concat = table.insert, table.concat

    local base, digits, labels = #seq, {}, {}
    for i = 1, base do rawset(digits, i, sub(seq, i, i)) end

    local maxlen = max_hint_len(size, base)
    local zeroseq = string.rep(rawget(digits, 1), maxlen)

    for n = 1, size do
        local t, i, j, d = {}, 1, n
        repeat
            d, n = (n % base) + 1, floor(n / base)
            rawset(t, i, rawget(digits, d))
            i = i + 1
        until n == 0

        rawset(labels, j, sub(zeroseq, 1, maxlen - i + 1)
            .. reverse(concat(t, "")))
    end
    return labels
end

-- Follow styles
styles = {
    charset = function (seq)
        assert(type(seq) == "string" and #seq > 0, "invalid sequence")
        return {
            maker = function (size) return charset(seq, size) end
        }
    end,

    numbers = function ()
        return {
            maker = function (size) return charset("0123456789", size) end
        }
    end,

    sort = function (style)
        local maker = style.maker
        style.maker = function (size)
            local labels = maker(size)
            table.sort(labels)
            return labels
        end
        return style
    end,

    reverse = function (style)
        local maker = style.maker
        style.maker = function (size)
            local rawset, rawget, reverse = rawset, rawget, string.reverse
            local labels = maker(size)
            for i = 1, #labels do
                rawset(labels, i, reverse(rawget(labels, i)))
            end
            return labels
        end
        return style
    end,

    no_text_match = function (style)
        style.no_text_match = true
        return style
    end,
}

-- Default follow style
style = styles.sort(styles.reverse(styles.numbers()))

local function api(w, frame, action, ...)
    local mode = w.follow_state.mode
    if action == "mode-options" then
        return {
            selector = mode.selector,
            stylesheet = mode.stylesheet or stylesheet
        }
    end
end

local function focus(w, step)
    local state = w.follow_state
    local view, frames, i = state.view, state.frames, state.focus_frame

    -- Asked to focus 1st elem & last focus was on different frame
    if i and step == 0 and i ~= 1 then
        view:eval_js("window.luakit_follow.unfocus()", frames[i])
        i = 1 -- start at first frame
    end

    i = i or 1       -- default to first frame on first focus
    local orig_i = i -- prevent inf loop

    local focus_call = (step == 0 and [=[luakit_follow.focus("first")]=])
        or string.format([=[luakit_follow.focus(%s)]=], step)

    while true do
        local d = assert(frames[i], "invalid index")
        local ret, err = view:eval_js(focus_call, d)
        assert(not err, err)

        -- Hint was focused
        if type(ret) == "number" then
            state.focus_frame = i
            return

        -- Focus first hint on next frame
        elseif ret == "next-frame" then
            if step < 0 then
                focus_call = [=[luakit_follow.focus("last")]=]
            end
            i = (step == 0 and i or i + step - 1) % #frames + 1
        end

        if i == orig_i then break end
    end

    state.focus_frame = nil
end

local eval_format = [=[(%s)(window.luakit_follow.focused_element())]=]
local function follow(w)
    local state = w.follow_state
    local view, mode = state.view, state.mode

    assert(type(state.focus_frame) == "number", "no frame focused")
    local d = assert(state.frames[state.focus_frame],
        "invalid focus frame index")

    local evaluator = string.format(eval_format, mode.evaluator)
    local ret, err = view:eval_js(evaluator, d)
    assert(not err, err)

    -- Leave follow mode
    w:set_mode()

    -- Call mode callback to deal with evaluator return
    if mode.func then mode.func(ret) end
end

new_mode("follow", {
    enter = function (w, mode)
        assert(type(mode) == "table", "invalid follow mode")
        local view = w.view
        local all_frames, frames = view.frames, {}

        local state = { mode = mode, view = view, frames = frames,
            ready_count = 0, time = capi.luakit.time() }
        w.follow_state = state


        local size = 0
        for _, f in ipairs(all_frames) do
            local d = { frame = f }

            -- Check if document ready and if follow lib already loaded
            local count, err = view:eval_js(init_js, d)
            assert(not err, err)

            -- Load follow lib
            if count == "first-run" then
                view:register_function("luakit_follow_api", function (...)
                    return api(w, f, ...)
                end, f)
                count = assert(view:eval_js(follow_js, d))
            end

            if type(count) == "number" and count > 0 then
                d.count, size = count, size + count
                table.insert(frames, d)
            end
        end


        -- No hintable items found
        if size == 0 then
            print("NOT HINTS GOUND")
            w:set_mode()
            w:notify("No matches...")
            return
        end

        -- Make all the labels
        local labels = _M.style.maker(size)

        -- Give each frame its hint labels
        local offset = 0
        for _, d in ipairs(frames) do
            local show = string.format("luakit_follow.show(%q)",
                table.concat(labels, " ", offset + 1, offset + d.count))
            local _, err = view:eval_js(show, d)
            assert(not err, err)
            offset = offset + d.count
        end

        if mode.prompt then
            w:set_prompt(string.format("Follow (%s):", mode.prompt))
        else
            w:set_prompt("Follow:")
        end

        w:set_input("")
    end,

    changed = function (w, text)
        local a = capi.luakit.time()
        local state = w.follow_state or {}
        local frames, view = state.frames, state.view
        local active_count, active_frame = 0

        for _, d in ipairs(frames) do
            local filter = string.format("luakit_follow.filter(%q)", text)
            local count, err = assert(view:eval_js(filter, d))
            if type(count) == "number" and count > 0 then
                active_frame = d
                active_count = active_count + count
            end
        end

        -- Focus first matching hint
        focus(w, 0)

        if active_count == 1 and text ~= "" then
            follow(w) -- follow the link
            return
        end
    end,

    leave = function (w)
        local state = w.follow_state or {}
        local view, frames = state.view, state.frames
        if not view or not frames then return end

        for _, d in ipairs(frames) do
            view:eval_js([=[window.luakit_follow.cleanup()]=], d)
        end
    end,
})

local key = lousy.bind.key
add_binds("follow", {
    key({},          "Tab",    function (w) focus(w,  1)    end),
    key({"Shift"},   "Tab",    function (w) focus(w, -1)    end),
    key({},          "Return", function (w) follow(w)       end),
})

selectors = {
    normal = 'a, area, textarea, select, input:not([type=hidden]), button',
    focus = 'a, area, textarea, select, input:not([type=hidden]), button, body, applet, object',
    uri = 'a, area',
    desc = '*[title], img[alt], applet[alt], area[alt], input[alt]',
    image = 'img, input[type=image]',
}

evaluators = {
    default = [=[function (element) {
        function click(element) {
            var mouse_event = document.createEvent("MouseEvent");
            mouse_event.initMouseEvent("click", true, true, window,
                0, 0, 0, 0, 0, false, false, false, false, 0, null);
            element.dispatchEvent(mouse_event);
        }

        var tag = element.tag;
        if (tag === "INPUT" || tag === "TEXTAREA") {
            var t = element.type.toUpperCase();
            if (t === "RADIO" || t == "CHECKBOX")
                element.checked = !element.checked;
            else if (t === "SUBMIT" || t === "RESET" || t === "BUTTON")
                click(element);
            else
                element.focus();
        } else
            click(element);

        return tag;
    }]=],

    focus = [=[function (element) {
        element.focus();
        return element.tag;
    }]=],

    uri = [=[function (element) {
        return element.src || element.href;
    }]=],

    desc = [=[function (element) {
        return element.title || element.alt;
    }]=],

    src = [=[function (element) {
        return element.src;
    }]=]
}

local s, e = selectors, evaluators
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^f$", function (w)
        w:set_mode("follow", {
            selector = s.normal, evaluator = e.default,
        })
    end),

    buf("^;;$", function (w)
        w:set_mode("follow", {
            prompt = "focus", selector = s.focus, evaluator = e.focus,
        })
    end),

    -- Open new tab
    buf("^F$", function (w)
        w:set_mode("follow", {
            prompt = "background tab", selector = s.uri, evaluator = e.uri,
            func = function (uri)
                assert(type(uri) == "string")
                w:new_tab(uri, false)
            end
        })
    end),

    -- Yank element uri or description into primary selection
    buf("^;y$", function (w)
        w:set_mode("follow", {
            prompt = "yank", selector = s.uri, evaluator = e.uri,
            func = function (uri)
                assert(type(uri) == "string")
                uri = string.gsub(uri, " ", "%%20")
                capi.luakit.selection.primary = uri
                w:notify("Yanked uri: " .. uri)
            end
        })
    end),

    -- Yank element description
    buf("^;Y$", function (w)
        w:set_mode("follow", {
            prompt = "yank desc", selector = s.desc, evaluator = e.desc,
            func = function (desc)
                assert(type(desc) == "string")
                capi.luakit.selection.primary = desc
                w:notify("Yanked desc: " .. desc)
            end
        })
    end),

    -- Follow a sequence of <CR> delimited hints in background tabs.
    buf("^;F$", function (w)
        w:set_mode("follow", {
            prompt = "multi-tab", selector = s.uri, evaluator = e.uri,
            func = function (uri)
                assert(type(uri) == "string")
                w:new_tab(uri, false)
                -- Re-enter follow mode with same mode
                w:set_mode("follow", w.follow_state.mode)
            end
        })
    end),

    -- Open image src
    buf("^;i$", function (w)
        w:set_mode("follow", {
            prompt = "open image", selector = s.image, evaluator = e.src,
            func = function (src)
                assert(type(src) == "string")
                w:navigate(src)
            end
        })
    end),

    -- Open image src in new tab
    buf("^;I$", function (w)
        w:set_mode("follow", {
            prompt = "tab image", selector = s.image, evaluator = e.src,
            func = function (src)
                assert(type(src) == "string")
                w:new_tab(src)
            end
        })
    end),

    -- Open link
    buf("^;o$", function (w)
        w:set_mode("follow", {
            prompt = "open", selector = s.uri, evaluator = e.uri,
            func = function (uri)
                assert(type(uri) == "string")
                w:navigate(uri)
            end
        })
    end),

    -- Open link in new tab
    buf("^;t$", function (w)
        w:set_mode("follow", {
            prompt = "open tab", selector = s.uri, evaluator = e.uri,
            func = function (uri)
                assert(type(uri) == "string")
                w:new_tab(uri)
            end
        })
    end),

    -- Open link in background tab
    buf("^;b$", function (w)
        w:set_mode("follow", {
            prompt = "background tab", selector = s.uri, evaluator = e.uri,
            func = function (uri)
                assert(type(uri) == "string")
                w:new_tab(uri, false)
            end
        })
    end),

    -- Open link in new window
    buf("^;w$", function (w)
        w:set_mode("follow", {
            prompt = "open window", selector = s.uri, evaluator = e.uri,
            func = function (uri)
                assert(type(uri) == "string")
                window.new{uri}
            end
        })
    end),

    -- Set command `:open <uri>`
    buf("^;O$", function (w,b,m)
        w:set_mode("follow", {
            prompt = ":open", selector = s.uri, evaluator = e.uri,
            func = function (uri)
                assert(type(uri) == "string")
                w:enter_cmd(":open " .. uri)
            end
        })
    end),

    -- Set command `:tabopen <uri>`
    buf("^;T$", function (w)
        w:set_mode("follow", {
            prompt = ":tabopen", selector = s.uri, evaluator = e.uri,
            func = function (uri)
                assert(type(uri) == "string")
                w:enter_cmd(":tabopen " .. uri)
            end
        })
    end),

    -- Set command `:winopen <uri>`
    buf("^;W$", function (w)
        w:set_mode("follow", {
            prompt = ":winopen", selector = s.uri, evaluator = e.uri,
            func = function (uri)
                assert(type(uri) == "string")
                w:enter_cmd(":winopen " .. uri)
            end
        })
    end),

--    -- Download uri
--    buf("^;s$", function (w,b,m)
--        w:start_follow(modes.uri, "download", function (uri)
--            downloads.add(uri)
--            return "root-active"
--        end)
--    end),
--
--    -- Download a sequence of <CR> delimited hints
--    buf("^;S$", function (w,b,m)
--        w:start_follow(modes.uri, "multi download", function (uri)
--            downloads.add(uri)
--            w:set_mode("follow") -- re-enter follow mode with same state
--        end)
--    end),
--
--	-- Set command `:qmark <cursor> <uri>`
--    buf("^;M%w$", function (w,b,m)
--        local token = string.match(b, "^;M(.)$")
--        w:start_follow(modes.uri, ":qmark " .. token, function (uri)
--            w:enter_cmd(string.format(":qmark %s %s", token, uri))
--        end)
--    end),
--
--    -- Set command `:bookmark <uri> `
--    buf("^;B$", function (w,b,m)
--        w:start_follow(modes.uri, ":bookmark", function (uri)
--            w:enter_cmd(":bookmark " .. uri .. " ")
--        end)
--    end),
})
