-----------------------------------------------------------------------
-- Simulating keystrokes                                             --
-- © 2010 Fabian Streitel (karottenreibe) (luakit@rottenrei.be)      --
-- © 2010 Mason Larobina  (mason-l)       (mason.larobina@gmail.com) --
-----------------------------------------------------------------------

--- Parses a vim-like keystring into single keys and sends them to the window.
-- A keystring is a string of keys to press, with special keys denoted in between
-- angle brackets:
--
--  <code>:o google<S-Tab>something<Return></code>
--
-- See gdk/gdkkeysyms.h for a complete list of recognized key names.
window.methods.send = function (w, keystring)
    local symbol = nil
    local modifiers = {}
    local keys = {}
    for char in string.gmatch(keystring, ".") do
        if char == "<" then
            symbol = ""
        elseif char == ">" and symbol then
            if #symbol == 0 then
                w:error("bad keystring: " .. keystring)
                return
            else
                table.insert(keys, {
                    key = symbol,
                    mods = modifiers,
                })
            end
            symbol = nil
            modifiers = {}
        elseif symbol and char == "-" then
            if string.match(symbol, "^[SCL]$") or string.match(symbol, "^M[1-5]$") then
                table.insert(modifiers, symbol)
                symbol = ""
            else
                w:error("bad modifier in keystring: " .. symbol)
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
    if symbol then
        w:error("bad keystring: " .. keystring)
        return
    end
    for _, key in ipairs(keys) do
        if not w.win:send_key(key.key, key.mods) then
            w:error("failed to send keystroke: " .. key)
            return
        end
    end
end

