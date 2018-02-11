--- Send keys for luakit.
--
-- This module parses a vim-like keystring into single keys and sends
-- them to the window. A keystring is a string of keys to press, with
-- special keys denoted in between angle brackets:
--
--     keysym.send(w, "<Shift-Home><BackSpace>")
--
-- See gdk/gdkkeysyms.h for a complete list of recognized key names.
--
-- @module keysym
-- @author Amos Bird amosbird@gmail.com
-- @author Fabian Streitel luakit@rottenrei.be
-- @author Mason Larobina mason.larobina@gmail.com
-- @copyright 2017 Amos Bird amosbird@gmail.com
-- @copyright 2010 Fabian Streitel luakit@rottenrei.be
-- @copyright 2010 Mason Larobina mason.larobina@gmail.com

local _M = {}

--- Send synthetic keys to given window.
-- This function parses a vim-like keystring into single keys and sends
-- them to the window. A keystring is a string of keys to press, with
-- special keys denoted in between angle brackets:
--
--     keysym.send(w, "<Shift-Home><BackSpace>")
--     keysym.send(w, "<Control-a>")
--
-- Sending special unicode characters needs related keyboard layout to be set.
--     keysym.send(w, "Приветствую, мир")
--
-- When `window.act_on_synthetic_keys` is disabled, synthetic key events will
-- not trigger other key bindings.
-- @tparam w The window object.
-- @tparam string keystring The key string representing synthetic keys.
_M.send = function (w, keystring)
    assert(type(w) == "table", "table expected, found "..type(w))
    assert(type(keystring) == "string", "string expected, found "..type(keystring))
    local symbol = nil
    local modifiers = {}
    local keys = {}
    for char in keystring:gmatch(utf8.charpattern) do
        if char == "<" then
            symbol = ""
        elseif char == ">" and symbol then
            if #symbol == 0 then
                error("bad keystring: " .. keystring)
            else
                table.insert(keys, {
                    key = symbol,
                    mods = modifiers,
                })
            end
            symbol = nil
            modifiers = {}
        elseif symbol and char == "-" then
            if symbol:match("^[Ss]hift$") or
                symbol:match("^[Cc]ontrol$") or
                symbol:match("^[Ll]ock$") or
                symbol:match("^[Mm]od[1-5]$")
            then
                table.insert(modifiers, symbol:lower())
                symbol = ""
            else
                error("bad modifier in keystring: " .. symbol)
                return
            end
        elseif not symbol then
            table.insert(keys, {
                key = char,
                mods = {},
            })
        else
            symbol = symbol .. char
        end
    end
    if symbol then error("unterminated symbol: " .. symbol) end
    for _, key in ipairs(keys) do
        w.win:send_key(key.key, key.mods)
    end
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
