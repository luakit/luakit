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
    luakit = luakit,
    timer = timer
}

module("follow")

-- After each follow ignore all keys pressed by the user to prevent the
-- accidental activation of other key bindings.
ignore_delay = 200

follow_js = [=[
window.luakit_follow = (function (window, document) {
    // Follow session state
    var state = {};

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
                left: left, top: top,
                width: right - left, height: bottom - top,
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
                + "px; width:" + h.width + "px; height:" + h.height
                + "px;'></span>" + "<span class='hint_label hint_label_" + tag
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

    function cleanup() {
        unlink(state.stylesheet);
        unlink(state.overlay);

        // Reset follow state
        state = {};
    }

    function init(selector, stylesheet) {
        var head = document.getElementsByTagName('head')[0],
            hints = eval_selector_make_hints(selector),
            style = create_stylesheet("luakit_follow_stylesheet", stylesheet);

        head.appendChild(style); // append follow stylesheet to <head>
        state.stylesheet = style;
        state.hints = state.filtered = hints;
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
        var hints = state.filtered, last = state.focused, i = 0;

        unfocus();

        // Nothing to focus in this frame
        if (hints.length === 0)
            return "next-frame";

        var labels = document.querySelectorAll("#luakit_follow_overlay .hint_overlay"),
            len = labels.length;

        // Focus first hint in this frame
        if (step === "first")
            i = 0

        // Focus last hint in this frame
        else if (step === "last")
            i = len - 1;

        // Focus hints[current + step]
        else if (last)
            i = last.index + step;

        // Out of bounds check = check next frame
        if (i >= len || i < 0)
            return "next-frame";

        e = labels[i];
        state.focused = { element: e, index: i, orig_class: e.className };
        e.className += " hint_selected";

        return i;
    }

    // Give all hints their labels and render the hint overlay.
    function show(labels) {
        var html = assign_labels_make_html(state.hints, labels.split(" "));
        show_hints(html);
    }

    function filter(hint_pat, text_pat) {
        var hpat = hint_pat !== "" && hint_pat,
            tpat = text_pat !== "" && text_pat, i = 0, html = "";

        // No filter patterns given, render all hints
        if (!hpat && !tpat) {
            var hints = state.hints, len = hints.length;
            for (; i < len;)
                html += hints[i++].html;
            show_hints(html);
            delete state.last_hpat;
            delete state.last_tpat;
            state.filtered = hints;
            return len;
        }

        // Check if we can cut corners by checking last filter patterns
        var last_hpat = state.last_hpat, last_tpat = state.last_tpat, hints;
        if (last_hpat || last_tpat) {
            // No action if new patterns equal last patterns
            if (last_hpat === hpat && last_tpat === tpat)
                return state.filtered.length;

            // Check type hasn't changed
            if (!!hpat === !!last_hpat && !!tpat === !!last_tpat) {
                // If new patterns are substrings of last patterns then we can
                // filter against the results of the last filter call
                if ((!hpat ||
                    hpat.substring(0, last_hpat.length) === last_hpat) &&
                    (!tpat ||
                    tpat.substring(0, last_tpat.length) === last_tpat)) {
                    hints = state.filtered;
                }
            }
        }

        // Patterns are different or it's our first run
        if (!hints)
            hints = state.hints;

        var hint_re = hpat && new RegExp(hpat),
            text_re = tpat && new RegExp(tpat),
            matches = [], len = hints.length, j = 0, h;

        // Filter hints
        for (; i < len;) {
            h = hints[i++];
            if ((hint_re && hint_re.test(h.label)) ||
                (text_re && text_re.test(h.text))) {
                matches[j++] = h;
                html += h.html;
            }
        }

        // Save info for next call
        state.last_hpat = hpat;
        state.last_tpat = tpat;
        state.filtered = matches;

        show_hints(html);

        return matches.length;
    }

    function focused_element() {
        return state.filtered[state.focused.index].element;
    }

    function visible_elements() {
        var hints = state.filtered, len = hints.length, elems = [], i = 0;
        for (; i < len; i++)
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
]=]

check_js = [=[
(function () {
    if (!document.body)
        return;

    return window.luakit_follow ? "ready" : "first-run";
})()
]=]

stylesheet = [===[
#luakit_follow_overlay {
    position: absolute;
    left: 0;
    top: 0;
}

#luakit_follow_overlay .hint_overlay {
    display: block;
    position: absolute;
    background-color: #ffff99;
    border: 1px dotted #000;
    opacity: 0.3;
    z-index: 10001;
}

#luakit_follow_overlay .hint_label {
    display: block;
    position: absolute;
    background-color: #000088;
    border: 1px dashed #000;
    color: #fff;
    font-size: 10px;
    font-family: monospace, courier, sans-serif;
    opacity: 0.4;
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

-- Different hint label styles
label_styles = {
    charset = function (seq)
        assert(type(seq) == "string" and #seq > 0, "invalid sequence")
        return function (size) return charset(seq, size) end
    end,

    numbers = function ()
        return function (size) return charset("0123456789", size) end
    end,

    -- Chainable style: sorts labels
    sort = function (make_labels)
        return function (size)
            local labels = make_labels(size)
            table.sort(labels)
            return labels
        end
    end,

    -- Chainable style: reverses label strings
    reverse = function (make_labels)
        return function (size)
            local rawset, rawget, reverse = rawset, rawget, string.reverse
            local labels = make_labels(size)
            for i = 1, #labels do
                rawset(labels, i, reverse(rawget(labels, i)))
            end
            return labels
        end
    end,
}

-- Default follow style
local s = label_styles
label_maker = s.sort(s.reverse(s.numbers()))

-- JavaScript regex escape function
local function regex_escape(s)
     local s = string.gsub(s, "([.?*+^$[%]\\(){}|-])", "\\%1")
     return s
end

-- Different hint matching styles
pattern_styles = {
    -- JavaScript regular expression match hint text
    re_match_text = function (text)
        return "", text
    end,

    -- JavaScript regex match hint labels & text
    re_match_both = function (text)
        return text, text
    end,

    -- String match hint label & regex match text
    match_label_re_text = function (text)
        return #text > 0 and "^"..regex_escape(text) or "", text
    end,

    -- Only match label
    match_label = function (text)
        return #text > 0 and "^"..regex_escape(text) or "", ""
    end,
}

-- Default pattern style
pattern_maker = pattern_styles.match_label_re_text

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

local eval_format = [=[
(%s)(window.luakit_follow.focused_element())
]=]

local hit_nop = function () return true end

local function ignore_keys(w)
    local delay = _M.ignore_delay
    if not delay or delay == 0 then return end
    -- Replace w:hit(..) with a no-op
    w.hit = hit_nop
    local t = capi.timer{ interval = delay }
    t:add_signal("timeout", function (t)
        t:stop()
        w.hit = nil
    end)
    t:start()
end

local function follow(w)
    local state = w.follow_state
    local view, mode = state.view, state.mode

    assert(type(state.focus_frame) == "number", "no frame focused")
    local d = assert(state.frames[state.focus_frame],
        "invalid focus frame index")

    local evaluator = string.format(eval_format, state.evaluator)
    local ret, err = view:eval_js(evaluator, d)
    assert(not err, err)

    if state.persist then
        w:set_mode("follow", mode)
    else
        w:set_mode()
    end

    -- Call mode callback to deal with evaluator return
    if mode.func then mode.func(ret) end

    ignore_keys(w)
end

local eval_all_format = [=[
(function (elems) {
    var evaluator = (%s);
    var ret = [], len = elems.length, i = 0, j = 0, val;
    for (; i < len;)
        if (val = evaluator(elems[i++]))
            ret[j++] = val;
    return ret;
})(window.luakit_follow.visible_elements())
]=]

local function follow_all_hints(w)
    local state = w.follow_state
    local view, mode = state.view, state.mode

    assert(type(state.focus_frame) == "number", "no frame focused")
    local d = assert(state.frames[state.focus_frame],
        "invalid focus frame index")

    local evaluator = string.format(eval_all_format, state.evaluator)
    local ret, err = view:eval_js(evaluator, d)
    assert(not err, err)

    if state.persist then
        w:set_mode("follow", mode)
    else
        w:set_mode()
    end

    -- Call mode callback to deal with evaluator return
    if mode.func then
        for _, v in ipairs(ret) do
            mode.func(v)
        end
    end

    ignore_keys(w)
end

new_mode("follow", {
    enter = function (w, mode)
        assert(type(mode) == "table", "invalid follow mode")

        local label_maker = mode.label_maker or _M.label_maker
        assert(type(label_maker) == "function",
            "invalid label_maker function")

        assert(type(mode.pattern_maker or _M.pattern_maker) == "function",
            "invalid pattern_maker function")

        local selector = mode.selector_func or _M.selectors[mode.selector]
        assert(type(selector) == "string", "invalid follow selector")

        local evaluator = mode.evaluator_func or _M.evaluators[mode.evaluator]
        assert(type(evaluator) == "string", "invalid follow evaluator")

        local stylesheet = mode.stylesheet or _M.stylesheet
        assert(type(stylesheet) == "string", "invalid stylesheet")

        local view = w.view
        local all_frames, frames = view.frames, {}

        local state = {
            mode = mode, view = view, frames = frames,
            evaluator = evaluator,
            persist = not not w.follow_persist
        }

        w.follow_state = state
        w.follow_persist = nil

        local init_js = string.format([=[luakit_follow.init(%q, %q)]=],
            selector, stylesheet)

        local size = 0
        for _, f in ipairs(all_frames) do
            local d, count = { frame = f }, 0

            -- Check if document ready and if follow lib already loaded
            local ret, err = view:eval_js(check_js, d)
            assert(not err, err)

            if ret == "first-run" then
                local _, err = view:eval_js(follow_js, d)
                assert(not err, err)
            end

            if ret then
                count, err = view:eval_js(init_js, d)
                assert(not err, err)
            end

            if count > 0 then
                d.count, size = count, size + count
                table.insert(frames, d)
            end
        end

        -- No hintable items found
        if size == 0 then
            w:set_mode()
            w:notify("No matches...")
            return
        end

        -- Make all the labels
        local labels = label_maker(size)

        -- Give each frame its hint labels
        local offset = 0
        for _, d in ipairs(frames) do
            local show = string.format([=[luakit_follow.show(%q)]=],
                table.concat(labels, " ", offset + 1, offset + d.count))
            local _, err = view:eval_js(show, d)
            assert(not err, err)
            offset = offset + d.count
        end

        focus(w, 0)

        if mode.prompt then
            w:set_prompt(string.format("Follow (%s):", mode.prompt))
        else
            w:set_prompt("Follow:")
        end

        w:set_input("")
    end,

    changed = function (w, text)
        local state = w.follow_state or {}
        local frames, mode = state.frames, state.mode
        local active_count = 0

        -- Make the hint label/text matching patterns
        local pattern_maker = mode.pattern_maker or _M.pattern_maker
        local hint_pat, text_pat = pattern_maker(text)

        local filter = string.format("luakit_follow.filter(%q, %q)",
            hint_pat or "", text_pat or "")

        for _, d in ipairs(frames) do
            local count, err = assert(state.view:eval_js(filter, d))
            if type(count) == "number" and count > 0 then
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
    key({},          "Tab",    function (w) focus(w,  1)        end),
    key({"Shift"},   "Tab",    function (w) focus(w, -1)        end),
    key({},          "Return", function (w) follow(w)           end),
    key({"Shift"},   "Return", function (w) follow_all_hints(w) end),
})

selectors = {
    clickable = 'a, area, textarea, select, input:not([type=hidden]), button',
    focus = 'a, area, textarea, select, input:not([type=hidden]), button, body, applet, object',
    uri = 'a, area',
    desc = '*[title], img[alt], applet[alt], area[alt], input[alt]',
    image = 'img, input[type=image]',
    thumbnail = "a img",
}

evaluators = {
    click = [=[function (element) {
        function click(element) {
            var mouse_event = document.createEvent("MouseEvent");
            mouse_event.initMouseEvent("click", true, true, window,
                0, 0, 0, 0, 0, false, false, false, false, 0, null);
            element.dispatchEvent(mouse_event);
        }

        var tag = element.tagName;
        if (tag === "INPUT" || tag === "TEXTAREA") {
            var t = element.type.toUpperCase();
            if (t === "RADIO" || t == "CHECKBOX")
                element.checked = !element.checked;
            else if (t === "SUBMIT" || t === "RESET" || t === "BUTTON")
                click(element);
            else {
                element.focus();
                return "form-active";
            }
        } else
            click(element);

        return "root-active";
    }]=],

    focus = [=[function (element) {
        element.focus();
        var tag = element.tagName;
        if (tag == "INPUT" || tag == "TEXTAREA")
            return "form-active";
        return "root-active";
    }]=],

    uri = [=[function (element) {
        return element.src || element.href;
    }]=],

    desc = [=[function (element) {
        return element.title || element.alt;
    }]=],

    src = [=[function (element) {
        return element.src;
    }]=],

    parent_href = [=[function (element) {
        return element.parentNode.href;
    }]=]
}

local buf = lousy.bind.buf
add_binds("normal", {
    buf("^f$", [[Start `follow` mode. Hint all clickable elements
        (as defined by the `follow.selectors.clickable`
        selector) and open links in the current tab.]],
        function (w)
            w:set_mode("follow", {
                selector = "clickable", evaluator = "click",
                func = function (s) w:emit_form_root_active_signal(s) end,
            })
        end),

    -- Open new tab
    buf("^F$", [[Start follow mode. Hint all links (as defined by the
        `follow.selectors.uri` selector) and open links in a new tab.]],
        function (w)
            w:set_mode("follow", {
                prompt = "background tab", selector = "uri", evaluator = "uri",
                func = function (uri)
                    assert(type(uri) == "string")
                    w:new_tab(uri, false)
                end
            })
        end),

    -- Start extended follow mode
    buf("^;$", [[Start `ex-follow` mode. See the [ex-follow](#mode-ex-follow)
        help section for the list of follow modes.]],
        function (w)
            w:set_mode("ex-follow")
        end),

    buf("^g;$", [[Start `ex-follow` mode and stay there until `<Escape>` is
        pressed.]],
        function (w)
            w:set_mode("ex-follow", true)
        end),
})

-- Extended follow mode
new_mode("ex-follow", {
    enter = function (w, persist)
        w.follow_persist = persist
    end,
})

add_binds("ex-follow", {
    key({}, ";", [[Hint all focusable elements (as defined by the
        `follow.selectors.focus` selector) and focus the matched element.]],
        function (w)
            w:set_mode("follow", {
                prompt = "focus", selector = "focus", evaluator = "focus",
                func = function (s) w:emit_form_root_active_signal(s) end,
            })
        end),

    -- Yank element uri or description into primary selection
    key({}, "y", [[Hint all links (as defined by the `follow.selectors.uri`
        selector) and set the primary selection to the matched elements URI.]],
        function (w)
            w:set_mode("follow", {
                prompt = "yank", selector = "uri", evaluator = "uri",
                func = function (uri)
                    assert(type(uri) == "string")
                    uri = string.gsub(uri, " ", "%%20")
                    capi.luakit.selection.primary = uri
                    w:notify("Yanked uri: " .. uri, false)
                end
            })
        end),

    -- Yank element description
    key({}, "Y", [[Hint all links (as defined by the `follow.selectors.uri`
        selector) and set the primary selection to the matched elements URI.]],
        function (w)
            w:set_mode("follow", {
                prompt = "yank desc", selector = "desc", evaluator = "desc",
                func = function (desc)
                    assert(type(desc) == "string")
                    capi.luakit.selection.primary = desc
                    w:notify("Yanked desc: " .. desc)
                end
            })
        end),

    -- Open image src
    key({}, "i", [[Hint all images (as defined by the `follow.selectors.image`
        selector) and open matching image location in the current tab.]],
        function (w)
            w:set_mode("follow", {
                prompt = "open image", selector = "image", evaluator = "src",
                func = function (src)
                    assert(type(src) == "string")
                    w:navigate(src)
                end
            })
        end),

    -- Open image src in new tab
    key({}, "I", [[Hint all images (as defined by the
        `follow.selectors.image` selector) and open matching image location in
        a new tab.]],
        function (w)
            w:set_mode("follow", {
                prompt = "tab image", selector = "image", evaluator = "src",
                func = function (src)
                    assert(type(src) == "string")
                    w:new_tab(src)
                end
            })
        end),

    -- Open thumbnail link
    key({}, "x", [[Hint all thumbnails (as defined by the
        `follow.selectors.thumbnail` selector) and open link in current tab.]],
        function (w)
            w:set_mode("follow", {
                prompt = "open image link",
                selector = "thumbnail", evaluator = "parent_href",
                func = function (uri)
                    assert(type(uri) == "string")
                    w:navigate(uri)
                end
            })
        end),

    -- Open thumbnail link in new tab
    key({}, "X", [[Hint all thumbnails (as defined by the
        `follow.selectors.thumbnail` selector) and open link in a new tab.]],
        function (w)
            w:set_mode("follow", {
                prompt = "tab image link", selector = "thumbnail",
                evaluator = "parent_href",
                func = function (uri)
                    assert(type(uri) == "string")
                    w:new_tab(uri, false)
                end
            })
        end),

    -- Open link
    key({}, "o", [[Hint all links (as defined by the `follow.selectors.uri`
        selector) and open its location in the current tab.]],
        function (w)
            w:set_mode("follow", {
                prompt = "open", selector = "uri", evaluator = "uri",
                func = function (uri)
                    assert(type(uri) == "string")
                    w:navigate(uri)
                end
            })
        end),

    -- Open link in new tab
    key({}, "t", [[Hint all links (as defined by the `follow.selectors.uri`
        selector) and open its location in a new tab.]],
        function (w)
            w:set_mode("follow", {
                prompt = "open tab", selector = "uri", evaluator = "uri",
                func = function (uri)
                    assert(type(uri) == "string")
                    w:new_tab(uri)
                end
            })
        end),

    -- Open link in background tab
    key({}, "b", [[Hint all links (as defined by the `follow.selectors.uri`
        selector) and open its location in a background tab.]],
        function (w)
            w:set_mode("follow", {
                prompt = "background tab", selector = "uri", evaluator = "uri",
                func = function (uri)
                    assert(type(uri) == "string")
                    w:new_tab(uri, false)
                end
            })
        end),

    -- Open link in new window
    key({}, "w", [[Hint all links (as defined by the `follow.selectors.uri`
        selector) and open its location in a new window.]],
        function (w)
            w:set_mode("follow", {
                prompt = "open window", selector = "uri", evaluator = "uri",
                func = function (uri)
                    assert(type(uri) == "string")
                    window.new{uri}
                end
            })
        end),

    -- Set command `:open <uri>`
    key({}, "O", [[Hint all links (as defined by the `follow.selectors.uri`
        selector) and generate a `:open` command with the elements URI.]],
        function (w)
            w:set_mode("follow", {
                prompt = ":open", selector = "uri", evaluator = "uri",
                func = function (uri)
                    assert(type(uri) == "string")
                    w:enter_cmd(":open " .. uri)
                end
            })
        end),

    -- Set command `:tabopen <uri>`
    key({}, "T", [[Hint all links (as defined by the `follow.selectors.uri`
        selector) and generate a `:tabopen` command with the elements URI.]],
        function (w)
            w:set_mode("follow", {
                prompt = ":tabopen", selector = "uri", evaluator = "uri",
                func = function (uri)
                    assert(type(uri) == "string")
                    w:enter_cmd(":tabopen " .. uri)
                end
            })
        end),

    -- Set command `:winopen <uri>`
    key({}, "W", [[Hint all links (as defined by the `follow.selectors.uri`
        selector) and generate a `:winopen` command with the elements URI.]],
        function (w)
            w:set_mode("follow", {
                prompt = ":winopen", selector = "uri", evaluator = "uri",
                func = function (uri)
                    assert(type(uri) == "string")
                    w:enter_cmd(":winopen " .. uri)
                end
            })
        end),
})
