--- Enables command history in modes that support it.
--
-- This module adds support for modes to specify that user input on the
-- command line should be recorded, so that users can scroll back through
-- previous input with the arrow keys. It is used to implement history for the
-- `command` mode.
--
-- @module cmdhist
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local window = require("window")
local lousy = require("lousy")
local modes = require("modes")

local _M = {}

-- Input bar history binds, these are only present in modes with a history
-- table so we can make some assumptions. This auto-magic is present when
-- a mode contains a `history` table item (with history settings therein).

--- Key binding for history prev command
-- @type string
-- @readwrite
_M.history_prev = "<Up>"

--- Key binding for history next command
-- @type string
-- @readwrite
_M.history_next = "<Down>"

local function filter (t, f)
    local T = {}
    for _, v in ipairs(t) do
        if v:find(f, 1, true) then
            table.insert(T, v)
        end
    end
    return T
end

--- Go to prev cmdhist item
_M.history_prev_func = function (w)
    local h = w.mode.history
    h.filtered = h.filtered or filter(h.items, w.ibar.input.text)
    local lc = h.cursor
    if not h.cursor and #h.filtered > 0 then
        h.cursor = #h.filtered
    elseif (h.cursor or 0) > 1 then
        h.cursor = h.cursor - 1
    end
    if h.cursor and h.cursor ~= lc then
        if not h.orig then h.orig = w.ibar.input.text end
        w:set_input(h.filtered[h.cursor])
    end
end

--- Go to next cmdhist item
_M.history_next_func = function (w)
    local h = w.mode.history
    if not h.cursor then return end
    if h.cursor >= #h.filtered then
        w:set_input(h.orig)
        h.cursor = nil
        h.orig = nil
        h.filtered = nil
    else
        h.cursor = h.cursor + 1
        w:set_input(h.filtered[h.cursor])
    end
end

modes.new_mode("cmdhist", [[A meta-mode to allow `modes.add_binds()` style key bindings for command history.
                            They will be applied to any other mode which has a `history` table.
                            The cmdhist mode should not be entered/activated.]], {
    enter = function (w) w:error("cmdhist mode was entered") end,
})
modes.add_binds("cmdhist", {
    { _M.history_prev, "Previous in command history.", _M.history_prev_func },
    { _M.history_next, "Next in command history.", _M.history_next_func },
})

window.add_signal("init", function (w)
    -- Add Prev & Next (and other user-specified) keybindings to modes which support command history
    for name,m in pairs(modes.get_modes()) do
        if m.history then
            modes.add_binds(name, modes.get_mode("cmdhist").binds)
        end
    end

    w:add_signal("mode-entered", function ()
        local mode = w.mode
        -- Setup history state
        if mode and mode.history then
            local h = mode.history
            -- Load history
            if not h.items then
                local f = io.open(luakit.data_dir .. "/command-history")
                if f then
                    h.items = lousy.pickle.unpickle(f:read("*a"))[mode.name]
                    f:close()
                end
                -- The function could return if history is empty
                h.items = h.items or {}
            end
            h.len = #(h.items)
            h.cursor = nil
            h.orig = nil
            h.filtered = nil
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
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
