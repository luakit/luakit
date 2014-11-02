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
        for i=1,m.count do w:search(nil, true)  end
    end, {count=1}),

    key({}, "N", "Find previous search result.", function (w, m)
        for i=1,m.count do w:search(nil, false) end
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
        w:clear_search(false)
    end,

    -- TODO this isn't happening at all
    changed = function (w, text)
        -- Check that the first character is '/' or '?' and update search
        if string.match(text, "^[?/]") then
            s = w.search_state
            s.last_search = string.sub(text, 2)
            if #text > 3 then
                s.event = "changed"
                w:search(string.sub(text, 2), (string.sub(text, 1, 1) == "/"))
            else
                w:clear_search(false)
            end
        else
            w:clear_search()
            w:set_mode()
        end
    end,

    activate = function (w, text)
        w.search_state.marker = nil
        -- TODO if uncommented this activates twice. Why?
        -- Search if haven't already (won't have for short strings)
--        if not w.search_state.searched then
--            w.search_state.event = "activate"
--            w:search(string.sub(text, 2), (string.sub(text, 1, 1) == "/"))
--        end
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
        if forward == nil then forward = true end

        -- Get search state (or new state)
        if not w.search_state then w.search_state = {} end
        local s = w.search_state

        -- boolean representing whether or not the current term text has
        -- been searched for or not. If so, need to call search_next() or
        -- search_previous() rather than search().
        s.has_searched_before = (s.searched and (text == s.last_search)) or ((not not s.last_search) and (text == nil or #text == 0))
        --print("has_searched_before:", text, s.last_search, s.has_searched_before, s.searched, text == s.last_search)

        -- Check if wrapping should be performed
        if wrap == nil then
            if s.wrap ~= nil then wrap = s.wrap else wrap = true end
        end

        -- Get search term
        text = text or s.last_search
        if not text or #text == 0 then
            return w:clear_search()
        end
        s.last_search = text

        if s.forward == nil then
            -- Haven't searched before, save some state.
            s.forward = forward
            s.wrap = wrap
            local scroll = view.scroll
            s.marker = { x = scroll.x, y = scroll.y }
        else
            -- Invert direction if originally searching in reverse
            forward = (s.forward == forward)
        end

        s.searched = true
        s.wrapped = false

        if s.has_searched_before then
            if forward then
                view:search_next()
            else
                view:search_previous()
            end
        else
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
        end
    end,

}) do webview.methods[k] = m end

webview.init_funcs.search_callbacks = function (view, w)
    view:add_signal("found-text", function (v, d)
        w.ibar.input.fg = theme.ibar_fg
        w.ibar.input.bg = theme.ibar_bg
        if not w.search_state.wrapped then
            w:set_mode()
            w:set_prompt(w.search_state.last_search)
        end
    end)

    view:add_signal("failed-to-find-text", function (v, d)
        w.ibar.input.fg = theme.ibar_error_fg
        w.ibar.input.bg = theme.ibar_error_bg
        if (not w.search_state.has_searched_before) or (w.search_state.wrap and not w.search_state.wrapped) then
            w.search_state.wrapped = true
            if w.search_state.forward then
                w:warning("Search hit BOTTOM, continuing at TOP")
            else
                w:warning("Search hit TOP, continuing at BOTTOM")
            end
            view:search(w.search_state.last_search, w.search_state.last_search ~= string.lower(w.search_state.last_search), w.search_state.forward, true);
        else
            --print(not w.search_state.has_searched_before, w.search_state.wrap, not w.search_state.wrapped)
            w:error("Pattern not found: " .. w.search_state.last_search)
        end
    end)
end

---- changed
--                if s.ret == false then
--                    if s.marker then w:scroll(s.marker) end
--                    w.ibar.input.fg = theme.ibar_error_fg
--                    w.ibar.input.bg = theme.ibar_error_bg
--                else
--                    w.ibar.input.fg = theme.ibar_fg
--                    w.ibar.input.bg = theme.ibar_bg
--                end
--
---- activate
--        -- Ghost the last search term
--        if w.search_state.ret then
--            w:set_mode()
--            w:set_prompt(text)
--        else
--            w:error("Pattern not found: " .. string.sub(text, 2))
--        end
---- inside actual search function
--            s.ret = view:search(text, text ~= string.lower(text), forward, s.wrapped);
--            if not s.ret and wrap then
--                s.wrapped = true
--                s.ret = view:search(text, text ~= string.lower(text), forward, s.wrapped);
--            end

-- vim: et:sw=4:ts=8:sts=4:tw=80
