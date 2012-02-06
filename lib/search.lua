------------------------------------------------------
-- Search for a string in the current webview       --
-- © 2010 Mason Larobina <mason.larobina@gmail.com> --
------------------------------------------------------

-- Add searching binds to normal mode
local key = lousy.bind.key
add_binds("normal", {
    key({}, "/", function (w) w:start_search("/") end),
    key({}, "?", function (w) w:start_search("?") end),

    key({}, "n", function (w, m)
        for i=1,m.count do w:search(nil, true)  end
        if w.search_state.ret == false then
            w:error("Pattern not found: " .. w.search_state.last_search)
        elseif w.search_state.wrapped then
            if w.search_state.forward then
                w:warning("Search hit BOTTOM, continuing at TOP")
            else
                w:warning("Search hit TOP, continuing at BOTTOM")
            end
        end
    end, {count=1}),

    key({}, "N", function (w, m)
        for i=1,m.count do w:search(nil, false) end
        if w.search_state.ret == false then
            w:error("Pattern not found: " .. w.search_state.last_search)
        elseif w.search_state.wrapped then
            if w.search_state.forward then
                w:warning("Search hit TOP, continuing at BOTTOM")
            else
                w:warning("Search hit BOTTOM, continuing at TOP")
            end
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
            s = w.search_state
            s.last_search = string.sub(text, 2)
            if #text > 3 then
                w:search(string.sub(text, 2), (string.sub(text, 1, 1) == "/"))
                if s.ret == false then
                    if s.marker then w:scroll(s.marker) end
                    w.ibar.input.fg = theme.ibar_error_fg
                    w.ibar.input.bg = theme.ibar_error_bg
                else
                    w.ibar.input.fg = theme.ibar_fg
                    w.ibar.input.bg = theme.ibar_bg
                end
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
        -- Search if haven't already (won't have for short strings)
        if not w.search_state.searched then
            w:search(string.sub(text, 2), (string.sub(text, 1, 1) == "/"))
        end
        -- Ghost the last search term
        if w.search_state.ret then
            w:set_mode()
            w:set_prompt(text)
        else
            w:error("Pattern not found: " .. string.sub(text, 2))
        end
    end,

    history = {maxlen = 50},
})

-- Add binds to search mode
add_binds("search", {
    key({"Control"}, "j", function (w)
        w:search(w.search_state.last_search, true)
    end),

    key({"Control"}, "k", function (w)
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
        s.ret = view:search(text, text ~= string.lower(text), forward, s.wrapped);
        if not s.ret and wrap then
            s.wrapped = true
            s.ret = view:search(text, text ~= string.lower(text), forward, s.wrapped);
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

-- vim: et:sw=4:ts=8:sts=4:tw=80
