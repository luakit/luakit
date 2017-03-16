--- Link hinting for luakit.
--
-- @module follow
-- @copyright 2010-2012 Mason Larobina  <mason.larobina@gmail.com>
-- @copyright 2010-2011 Fabian Streitel <karottenreibe@gmail.com>

local lousy = require "lousy"
local window = require("window")
local new_mode = require("modes").new_mode
local binds = require("binds")
local add_binds = binds.add_binds
local capi = {
    luakit = luakit,
    timer = timer
}

local _M = {}

local follow_wm = require_web_module("follow_wm")

--- Duration to ignore keypresses after following a hint. 200ms by default.
--
-- After each follow ignore all keys pressed by the user to prevent the
-- accidental activation of other key bindings.
_M.ignore_delay = 200

--- CSS applied to the follow mode overlay.
_M.stylesheet = [===[
#luakit_select_overlay {
    position: absolute;
    left: 0;
    top: 0;
    z-index: 2147483647; /* Maximum allowable on WebKit */
}

#luakit_select_overlay .hint_overlay {
    display: block;
    position: absolute;
    background-color: #ffff99;
    border: 1px dotted #000;
    opacity: 0.3;
}

#luakit_select_overlay .hint_label {
    display: block;
    position: absolute;
    background-color: #000088;
    border: 1px dashed #000;
    color: #fff;
    font-size: 10px;
    font-family: monospace, courier, sans-serif;
    opacity: 0.4;
}

#luakit_select_overlay .hint_overlay_body {
    background-color: #ff0000;
}

#luakit_select_overlay .hint_selected {
    background-color: #00ff00 !important;
}
]===]

-- Lua regex escape function
local function regex_escape(s)
    local escape_chars = "%^$().[]*+-?"
    local escape_pat = '([' .. escape_chars:gsub("(.)", "%%%1") .. '])'
    return s:gsub(escape_pat, "%%%1")
end

local re_match_text = function (text) return "", text end
local re_match_both = function (text) return text, text end
local match_label_re_text = function (text)
    return #text > 0 and "^"..regex_escape(text) or "", text
end
local match_label = function (text)
    return #text > 0 and "^"..regex_escape(text) or "", ""
end

--- Table of functions used to select a hint matching style.
_M.pattern_styles = {
    re_match_text = re_match_text, -- Regex match target text only.
    re_match_both = re_match_both, -- Regex match both hint label or target text
    match_label_re_text = match_label_re_text, -- String match hint label & regex match text
    match_label = match_label, -- String match hint label only
}

--- Hint matching style functions.
_M.pattern_maker = _M.pattern_styles.match_label_re_text

--- Whether text case should be ignored in follow mode. True by default.
_M.ignore_case = true

local function focus(w, step)
    follow_wm:emit_signal(w.view, "focus", step)
end

local hit_nop = function () return true end

local function ignore_keys(w)
    local delay = _M.ignore_delay
    if not delay or delay == 0 then return end
    -- Replace w:hit(..) with a no-op
    w.hit = hit_nop
    local timer = capi.timer{ interval = delay }
    timer:add_signal("timeout", function (t)
        t:stop()
        w.hit = nil
    end)
    timer:start()
end

local function do_follow(w, all)
    follow_wm:emit_signal(w.view, "follow", all)
end

local function follow_all_hints(w)
    do_follow(w, true)
end

local function follow_func_cb(w, ret)
    local mode = w.follow_state.mode

    if mode.func then mode.func(ret) end

    if mode.persist then
        w:set_input("")
        w:set_mode("follow", mode)
    elseif ret ~= "form-active" and ret ~= "root-active" then
        w:set_mode()
    end

    ignore_keys(w)
end

local function matches_cb(w, n)
    w:set_ibar_theme(n > 0 and "ok" or "error")
end

follow_wm:add_signal("follow_func", function(_, page_id, ret)
    for _, w in pairs(window.bywidget) do
        if w.view.id == page_id then follow_func_cb(w, ret) end
    end
end)
follow_wm:add_signal("matches", function(_, page_id, n)
    for _, w in pairs(window.bywidget) do
        if w.view.id == page_id then matches_cb(w, n) end
    end
end)

new_mode("follow", {
    enter = function (w, mode)
        assert(type(mode) == "table", "invalid follow mode")

        if mode.label_maker then
            msg.warn("Custom label maker not yet implemented!")
        end

        assert(type(mode.pattern_maker or _M.pattern_maker) == "function",
            "invalid pattern_maker function")

        local selector = mode.selector_func or _M.selectors[mode.selector]
        assert(type(selector) == "string", "invalid follow selector")
        mode.selector = selector

        local stylesheet = mode.stylesheet or _M.stylesheet
        assert(type(stylesheet) == "string", "invalid stylesheet")
        mode.stylesheet = stylesheet

        local view = w.view

        if w.follow_persist then
            mode.persist = true
            w.follow_persist = nil
        end

        w.follow_state = {
            mode = mode, view = view,
            evaluator = mode.evaluator,
        }

        if mode.prompt then
            w:set_prompt(string.format("Follow (%s):", mode.prompt))
        else
            w:set_prompt("Follow:")
        end

        w:set_input("")
        w:set_ibar_theme()

        -- Cut func out of mode, since we can't send functions
        local func = mode.func
        mode.func = nil
        follow_wm:emit_signal(w.view, "enter", mode, _M.ignore_case)
        mode.func = func
    end,

    changed = function (w, text)
        local mode = w.follow_state.mode

        -- Make the hint label/text matching patterns
        local pattern_maker = mode.pattern_maker or _M.pattern_maker
        local hint_pat, text_pat = pattern_maker(text)

        follow_wm:emit_signal(w.view, "changed", hint_pat, text_pat, text)
    end,

    leave = function (w)
        w:set_ibar_theme()
        follow_wm:emit_signal(w.view, "leave")
    end,
})

local key = lousy.bind.key
add_binds("follow", {
    key({},          "Tab",    function (w) focus(w,  1)        end),
    key({"Shift"},   "Tab",    function (w) focus(w, -1)        end),
    key({},          "Return", function (w) do_follow(w)        end),
    key({"Shift"},   "Return", function (w) follow_all_hints(w) end),
})

--- Element selectors used to filter elements to follow.
_M.selectors = {
    clickable = 'a, area, textarea, select, input:not([type=hidden]), button',
    -- Elements that can be clicked.
    focus = 'a, area, textarea, select, input:not([type=hidden]), button, body, applet, object',
    -- Elements that can be given input focus.
    uri = 'a, area',
    -- Elements that have a URI (e.g. hyperlinks).
    desc = '*[title], img[alt], applet[alt], area[alt], input[alt]',
    -- Elements that can have a description.
    image = 'img, input[type=image]',
    -- Image elements.
    thumbnail = "a img",
    -- Image elements within a hyperlink.
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

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
