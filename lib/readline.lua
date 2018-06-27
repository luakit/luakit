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
local prev_glyph = lousy.util.string.prev_glyph
local next_glyph = lousy.util.string.next_glyph

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
            if text and utf8.len(text) > 1 and pos > 1 then
                local left = string.sub(text, 2, utf8.offset(text, pos))
                local right = string.sub(text, utf8.offset(text, pos + 1))
                if not string.find(left, "%s") then
                    left = ""
                elseif string.find(left, "%S+%s*$") then
                    left = string.sub(left, 0, string.find(left, "%S+%s*$") - 1)
                elseif string.find(left, "%W+%s*$") then
                    left = string.sub(left, 0, string.find(left, "%W+%s*$") - 1)
                end
                i.text =  string.sub(text, 1, 1) .. left .. right
                i.position = utf8.len(left) + 1
            end
        end,
        desc = "Delete previous word.",
    },
    del_word_backward = {
        func = function (w)
            local i = w.ibar.input
            local text = i.text
            local pos = i.position
            if text and utf8.len(text) > 1 and pos > 1 then
                local right = string.sub(text, utf8.offset(text, pos + 1))
                pos = utf8.offset(text, pos) - 1
                while true
                do
                    local new_pos, glyph = prev_glyph(text, pos)
                    if not new_pos or (glyph:len() == 1 and not glyph:find("%w")) then
                        break
                    end
                    pos = new_pos
                end
                local left = ""
                if pos then
                    left = text:sub(2, pos)
                end
                i.text =  text:sub(1, 1) .. left .. right
                i.position = utf8.len(left) + 1
            end
        end,
        desc = "Delete word backward.",
    },
    del_word_forward = {
        func = function (w)
            local i = w.ibar.input
            local text = i.text
            local pos = i.position
            if text and utf8.len(text) > 1 and pos < utf8.len(text) then
                -- include current character
                local left = text:sub(1, utf8.offset(text, pos + 1) - 1)
                -- at least delete one character
                pos = utf8.offset(text, pos + 2)
                while true
                do
                    local new_pos, glyph = next_glyph(text, pos)
                    if not new_pos or (glyph:len() == 1 and not glyph:find("%w")) then
                        break
                    end
                    pos = new_pos
                end
                local right
                if pos then
                    right = text:sub(pos)
                else
                    right = ""
                end
                i.text = left .. right
                i.position = utf8.len(left)
            end
        end,
        desc = "Delete word forward.",
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
    del_to_eol = {
        func = function (w)
            local i = w.ibar.input
            local text = i.text
            local pos = i.position
            if not string.match(text, "^[:/?]$") then
                i.text = string.sub(text, 1, pos)
                i.position = pos
            end
        end,
        desc = "Delete to the end of current line.",
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
            if text and utf8.len(text) > 1 then
                pos = pos + 1
                local raw_pos = utf8.offset(text, pos + 1)
                while true
                do
                    local glyph
                    raw_pos, glyph = next_glyph(text, raw_pos)
                    if not raw_pos or (glyph:len() == 1 and not glyph:find("%w")) then
                        break
                    end
                    pos = pos + 1
                end
                i.position = pos
            end
        end,
        desc = "Move cursor forward one word.",
    },
    backward_word = {
        func = function (w)
            local i = w.ibar.input
            local text = i.text
            local pos = i.position
            if text and utf8.len(text) > 1 and pos > 1 then
                local raw_pos = utf8.offset(text, pos) - 1
                while true
                do
                    local glyph
                    raw_pos, glyph = prev_glyph(text, raw_pos)
                    pos = pos - 1
                    if not raw_pos or (glyph:len() == 1 and not glyph:find("%w")) then
                        break
                    end
                end
                if not pos then
                    i.position = 1
                else
                    i.position = pos
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
    { "<Shift-Insert>",       actions.paste                , {} },
    { "<Control-w>",          actions.del_word             , {} },
    { "<Mod1-BackSpace>",     actions.del_word_backward    , {} },
    { "<Mod1-d>",             actions.del_word_forward     , {} },
    { "<Control-u>",          actions.del_line             , {} },
    { "<Control-o>",          actions.del_to_eol           , {} },
    { "<Control-h>",          actions.del_backward_char    , {} },
    { "<Control-d>",          actions.del_forward_char     , {} },
    { "<Control-a>",          actions.beg_line             , {} },
    { "<Control-e>",          actions.end_line             , {} },
    { "<Control-f>",          actions.forward_char         , {} },
    { "<Control-b>",          actions.backward_char        , {} },
    { "<Mod1-f>",             actions.forward_word         , {} },
    { "<Mod1-b>",             actions.backward_word        , {} },
    { "<Control-y>",          actions.yank_text            , {} },
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
