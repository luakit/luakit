--- Search for a string in the current webview.
--
-- This module allows you to search for a string of text in the currently
-- visible web page. A history of search terms is kept while luakit is running.
--
-- *Note: regular expressions are not supported.*
--
-- @module search
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local webview = require("webview")
local new_mode = require("modes").new_mode
local add_binds = require("modes").add_binds

local _M = {}

-- Add searching binds to normal mode
add_binds("normal", {
    { "/", "Search for string on current page.",
        function (w) w:start_search("/") end },
    { "?", "Reverse search for string on current page.",
        function (w) w:start_search("?") end },
    { "n", "Find next search result.", function (w, m)
        for _=1,m.count do
            w:search(nil, true)
            if w.search_state.by_view[w.view].ret == false then
                break
            end
        end
    end, {count=1} },
    { "N", "Find previous search result.", function (w, m)
        for _=1,m.count do
            w:search(nil, false)
            if w.search_state.by_view[w.view].ret == false then
                break
            end
        end
    end, {count=1} },
})

local function new_search_state()
    return { by_view = setmetatable({}, { __mode = "k" }) }
end

-- Setup search mode
new_mode("search", {
    enter = function (w)
        -- Clear old search state
        w.search_state = new_search_state()
        w:set_prompt()
        w:set_input("/")
    end,

    leave = function (w)
        w:set_ibar_theme()
        -- Check if search was aborted and return to original position
        local s = w.search_state
        if s.marker then
            w:scroll(s.marker)
            s.marker = nil
        end
    end,

    changed = function (w, text)
        -- Check that the first character is '/' or '?' and update search
        if string.match(text, "^[?/]") then
            local prefix = string.sub(text, 1, 1)
            local search = string.sub(text, 2)
            w:search(search, (prefix == "/"))
        else
            w:clear_search()
            w:set_mode()
        end
    end,

    activate = function (w, text)
        w.search_state.marker = nil
        if text == "/" or text == "?" then
            w:clear_search()
        end
        w:set_mode()
    end,

    history = {maxlen = 50},
})

-- Add binds to search mode
add_binds("search", {
    { "<Control-j>", "Select next search result.", function (w)
        w:search(w.search_state.last_search, true)
    end },
    { "<Control-k>", "Select previous result.", function (w)
        w:search(w.search_state.last_search, false)
    end },
})

-- Add search functions to webview
for k, m in pairs({
    start_search = function (_, w, text)
        if string.match(text, "^[?/]") then
            w:set_mode("search")
            if not string.match(text, "^/$") then w:set_input(text) end
        else
            return error("invalid search term, must start with '?' or '/'")
        end
    end,

    search = function (view, w, text, forward, wrap)
        -- Get search state (or new state)
        if not w.search_state then w.search_state = new_search_state() end
        local s = w.search_state

        if not s.by_view[view] then
            s.by_view[view] = {}
        end

        -- Default values
        if forward == nil then forward = true end
        text = text or s.last_search or ""

        -- Check if wrapping should be performed
        if wrap == nil then
            if s.wrap ~= nil then wrap = s.wrap else wrap = true end
        end

        if text == "" then
            if w:is_mode("search") then
                return w:clear_search()
            else
                return w:notify("No search term specified")
            end
        end

        if not s.searched then
            -- Haven't searched before, save some state.
            s.forward = forward
            s.wrap = wrap
            local scroll = view.scroll
            s.marker = { x = scroll.x, y = scroll.y }
        end
        s.searched = true

        -- Invert direction if originally searching in reverse
        forward = (s.forward == forward)

        if text == s.by_view[view].last_search then
            if forward then
                view:search_next()
            else
                view:search_previous()
            end
        else
            s.by_view[view].search = text
            s.last_search = text
            view:search(text, text ~= string.lower(text), forward, wrap)
        end
    end,

    clear_search = function (view, w, clear_state)
        w:set_ibar_theme()
        view:clear_search()
        if clear_state ~= false then
            w.search_state = new_search_state()
        else
            w.search_state.searched = false
            w.search_state.last_search = nil
        end
    end,

}) do webview.methods[k] = m end

webview.add_signal("init", function (view)
    view:add_signal("found-text", function (v)
        local w = webview.window(v)
        w.search_state.by_view[v].ret = true
        w:set_ibar_theme()
    end)

    view:add_signal("failed-to-find-text", function (v)
        local w = webview.window(v)
        w.search_state.by_view[v].ret = false
        w:set_ibar_theme("error")
        if not w:is_mode("search") then
            w:error("not found: " .. w.search_state.last_search)
        end

        local s = w.search_state
        if s.marker then w:scroll(s.marker) end
    end)

    -- Clear start search marker on button press/release
    local clear_start_search_marker = function (v)
        local w = webview.window(v)
        if w.search_state then w.search_state.marker = nil end
    end
    view:add_signal("button-press", clear_start_search_marker)
    view:add_signal("button-release", clear_start_search_marker)
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
