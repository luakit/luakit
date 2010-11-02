--------------------------------------------------------
-- Enables command history in modes that support it   --
-- (C) 2010 Mason Larobina <mason.larobina@gmail.com> --
--------------------------------------------------------

-- Input bar history binds, these are only present in modes with a history
-- table so we can make some assumptions. This auto-magic is present when
-- a mode contains a `history` table item (with history settings therein).
local key = lousy.bind.key
local hist_binds = {
    key({}, "Up", function (w)
        local h = w.mode.history
        local lc = h.cursor
        if not h.cursor and h.len > 0 then
            h.cursor = h.len
        elseif (h.cursor or 0) > 1 then
            h.cursor = h.cursor - 1
        end
        if h.cursor and h.cursor ~= lc then
            if not h.orig then h.orig = w.ibar.input.text end
            w:set_input(h.items[h.cursor])
        end
    end),

    key({}, "Down", function (w)
        local h = w.mode.history
        if not h.cursor then return end
        if (h.cursor + 1) >= h.len then
            w:set_input(h.orig)
            h.cursor = nil
            h.orig = nil
        else
            h.cursor = h.cursor + 1
            w:set_input(h.items[h.cursor])
        end
    end),
}

-- Add the Up & Down keybindings to modes which support command history
window.init_funcs.add_hist_binds = function (w)
    w:add_signal("mode-entered", function ()
        local mode = w.mode
        -- Setup history state
        if mode and mode.history then
            local h = mode.history
            if not h.items then h.items = {} end
            h.len = #(h.items)
            h.cursor = nil
            h.orig = nil
            -- Add Up & Down history bindings
            for _, b in ipairs(hist_binds) do
                table.insert(w.binds, b)
            end
            -- Trim history
            if h.maxlen and h.len > (h.maxlen * 1.5) then
                local items = {}
                for i = (h.len - h.maxlen), h.len do
                    table.insert(items, h.items[i])
                end
                h.items = items
                h.len = #items
            end
        end
    end)
end
