------------------------------------------------------
-- Search for a string in the current webview       --
-- © 2010 Mason Larobina <mason.larobina@gmail.com> --
------------------------------------------------------

-- Add searching binds to normal mode
local key = lousy.bind.key
add_binds("normal", {
    key({}, "/", "Search for string on current page.",
        function (w) w:start_search("/") end),

    key({}, "?", "Reverse search for string on current page.",
        function (w) w:start_search("?") end),

    key({}, "n", "Find next search result.", function (w, m)
        for i=1,m.count do
            if w.search_state.ret == false then
                w:error("not found: " .. w.search_state.last_search)
                break
            end
            w:search(nil, true)
        end
    end, {count=1}),

    key({}, "N", "Find previous search result.", function (w, m)
        for i=1,m.count do
            if w.search_state.ret == false then
                w:error("not found: " .. w.search_state.last_search)
                break
            end
            w:search(nil, false)
        end
    end, {count=1}),
})

-- Setup search mode
new_mode("search", {
    enter = function (w)
        -- Clear old search state
        w.search_state = {}
        w:set_prompt()
        w:set_input("/")
    end,

    leave = function (w)
        w.ibar.input.fg = theme.ibar_fg
        w.ibar.input.bg = theme.ibar_bg
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
        w:set_mode()
    end,

    history = {maxlen = 50},
})

-- Add binds to search mode
add_binds("search", {
    key({"Control"}, "j", "Select next search result.", function (w)
        w:search(w.search_state.last_search, true)
    end),

    key({"Control"}, "k", "Select previous result.", function (w)
        w:search(w.search_state.last_search, false)
    end),
})

-- Add search functions to webview
for k, m in pairs({
    start_search = function (view, w, text)
        if string.match(text, "^[?/]") then
            w:set_mode("search")
            if not string.match(text, "^/$") then w:set_input(text) end
        else
            return error("invalid search term, must start with '?' or '/'")
        end
    end,

    search = function (view, w, text, forward, wrap)
        -- Get search state (or new state)
        if not w.search_state then w.search_state = {} end
        local s = w.search_state

        -- Default values
        if forward == nil then forward = true end
        text = text or s.last_search or ""

        -- Check if wrapping should be performed
        if wrap == nil then
            if s.wrap ~= nil then wrap = s.wrap else wrap = true end
        end

        if text == "" then
            return w:clear_search()
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

        if text == s.last_search then
            if forward then
                view:search_next()
            else
                view:search_previous()
            end
        else
            s.last_search = text
            view:search(text, text ~= string.lower(text), forward, wrap)
        end
    end,

    clear_search = function (view, w, clear_state)
        w.ibar.input.fg = theme.ibar_fg
        w.ibar.input.bg = theme.ibar_bg
        view:clear_search()
        if clear_state ~= false then
            w.search_state = {}
        else
            w.search_state.searched = false
            w.search_state.last_search = nil
        end
    end,

}) do webview.methods[k] = m end

webview.init_funcs.search_callbacks = function (view, w)
    view:add_signal("found-text", function (v, d)
        w.search_state.ret = true
        w.ibar.input.fg = theme.ibar_fg
        w.ibar.input.bg = theme.ibar_bg
    end)

    view:add_signal("failed-to-find-text", function (v, d)
        w.search_state.ret = false
        w.ibar.input.fg = theme.ibar_error_fg
        w.ibar.input.bg = theme.ibar_error_bg

        local s = w.search_state
        if s.marker then w:scroll(s.marker) end
    end)
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
