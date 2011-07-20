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
            if string.match(symbol, "S(hift)?|C(ontrol)?|L(ock)?|M(od)?[12345]") then
                for short, long in pairs({
                    S = "Shift",
                    C = "Control",
                    L = "Lock",
                    M1 = "Mod1",
                    M2 = "Mod2",
                    M3 = "Mod3",
                    M4 = "Mod4",
                    M5 = "Mod5",
                }) do
                    if symbol == short then
                        symbol = long
                        break
                    end
                end
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

