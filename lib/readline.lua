--- Add readline bindings to the input bar.
--
-- This module adds a set of readline-inspired bindings to the input bar. These
-- bindings are not bound to any specific mode, but are automatically activated
-- whenever the input bar has focus.
--
-- @module readline
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local window = require "window"
local lousy = require "lousy"

local _M = {}

local yank_ring = ""

local actions =  {
    paste = {
        func = function (w)
            local str = luakit.selection.primary
            if not str then return end
            local i = w.ibar.input
            local text = i.text
            local pos = i.position
            local left, right = string.sub(text, 1, pos), string.sub(text, pos+1)
            i.text = left .. str .. right
            i.position = pos + #str
        end,
        desc = "Insert contents of primary selection at cursor position.",
    },
    del_word = {
        func = function (w)
            local i = w.ibar.input
            local text = i.text
            local pos = i.position
            if text and string.wlen(text) > 1 and pos > 1 then
                local left = string.sub(text, 2, string.woffset(text, pos - 1))
                local right = string.sub(text, string.woffset(text, pos))
                if not string.find(left, "%s") then
                    left = ""
                elseif string.find(left, "%S+%s*$") then
                    left = string.sub(left, 0, string.find(left, "%S+%s*$") - 1)
                elseif string.find(left, "%W+%s*$") then
                    left = string.sub(left, 0, string.find(left, "%W+%s*$") - 1)
                end
                i.text =  string.sub(text, 1, 1) .. left .. right
                i.position = string.wlen(left) + 1
            end
        end,
        desc = "Delete previous word.",
    },
    del_line = {
        func = function (w)
            local i = w.ibar.input
            if not string.match(i.text, "^[:/?]$") then
                yank_ring = string.sub(i.text, 2)
                i.text = string.sub(i.text, 1, 1)
                i.position = -1
            end
        end,
        desc = "Delete until beginning of current line.",
    },
    del_backward_char = {
        func = function (w)
            local i = w.ibar.input
            local text = i.text
            local pos = i.position

            if pos > 1 then
                i.text = string.sub(text, 0, pos - 1) .. string.sub(text, pos + 1)
                i.position = pos - 1
            end
        end,
        desc = "Delete character to the left.",
    },
    del_forward_char = {
        func = function (w)
            local i = w.ibar.input
            local text = i.text
            local pos = i.position

            i.text = string.sub(text, 0, pos) .. string.sub(text, pos + 2)
            i.position = pos
        end,
        desc = "Delete character to the right.",
    },
    beg_line = {
        func = function (w)
            local i = w.ibar.input
            i.position = 1
        end,
        desc = "Move cursor to beginning of current line.",
    },
    end_line = {
        func = function (w)
            local i = w.ibar.input
            i.position = -1
        end,
        desc = "Move cursor to end of current line.",
    },
    forward_char = {
        func = function (w)
            local i = w.ibar.input
            i.position = i.position + 1
        end,
        desc = "Move cursor forward one character.",
    },
    backward_char = {
        func = function (w)
            local i = w.ibar.input
            local pos = i.position
            if pos > 1 then
                i.position = pos - 1
            end
        end,
        desc = "Move cursor backward one character.",
    },
    forward_word = {
        func = function (w)
            local i = w.ibar.input
            local text = i.text
            local pos = i.position
            if text and #text > 1 then
                local right = string.sub(text, pos+1)
                if string.find(right, "%w+") then
                    local _, move = string.find(right, "%w+")
                    i.position = pos + move
                end
            end
        end,
        desc = "Move cursor forward one word.",
    },
    backward_word = {
        func = function (w)
            local i = w.ibar.input
            local text = i.text
            local pos = i.position
            if text and #text > 1 and pos > 1 then
                local left = string.reverse(string.sub(text, 2, pos))
                if string.find(left, "%w+") then
                    local _, move = string.find(left, "%w+")
                    i.position = pos - move
                end
            end
        end,
        desc = "Move cursor backward one word.",
    },
    yank_text = {
        func = function (w)
            local i = w.ibar.input
            local text = i.text
            local pos = i.position
            local left, right = string.sub(text, 1, pos), string.sub(text, pos+1)
            i.text = left .. yank_ring .. right
            i.position = pos + #yank_ring
        end,
        desc = "Yank the most recently killed text into the input bar, at the cursor.",
    },
}

--- Table of bindings that are added to the input bar.
-- @readwrite
-- @type table
_M.bindings = {
    { "<Shift-Insert>", actions.paste            , {} },
    { "<Control-w>",    actions.del_word         , {} },
    { "<Control-u>",    actions.del_line         , {} },
    { "<Control-h>",    actions.del_backward_char, {} },
    { "<Control-d>",    actions.del_forward_char , {} },
    { "<Control-a>",    actions.beg_line         , {} },
    { "<Control-e>",    actions.end_line         , {} },
    { "<Control-f>",    actions.forward_char     , {} },
    { "<Control-b>",    actions.backward_char    , {} },
    { "<Mod1-f>",       actions.forward_word     , {} },
    { "<Mod1-b>",       actions.backward_word    , {} },
    { "<Control-y>",    actions.yank_text        , {} },
}

window.add_signal("init", function (w)
    w.ibar.input:add_signal("key-press", function (input, mods, key)
        local ww = assert(window.ancestor(input)) -- Unlikely, but just in case
        local success, match = xpcall(
            function () return lousy.bind.hit(ww, _M.bindings, mods, key, {}) end,
            function (err) w:error(debug.traceback(err, 2)) end)
        if success and match then
            return true
        end
    end)
end)

-- Check for old config/window.lua
for k in pairs(actions) do
    k = k == "paste" and "insert_cmd" or k
    for wm in pairs(window.methods) do
        if k == wm then
            msg.warn("detected old window.lua: method '%s'", wm)
            msg.warn("  readline bindings have been moved to readline.lua")
            msg.warn("  you should remove this method from your config/window.lua")
        end
    end
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
