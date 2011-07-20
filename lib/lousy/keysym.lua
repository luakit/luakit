-----------------------------------------------------------------------
-- Simulating keystrokes                                             --
-- © 2010 Fabian Streitel (karottenreibe) (luakit@rottenrei.be)      --
-- © 2010 Mason Larobina  (mason-l)       (mason.larobina@gmail.com) --
-----------------------------------------------------------------------

--- Parses a vim-like keystring into single keys and sends them to the window.
-- A keystring is a string of keys to press, with special keys denoted in between
-- angle brackets:
--
--  <code>:o google<Tab>something<Return></code>
--
-- See gdk/gdkkeysyms.h for a complete list of recognized key names.
window.methods.send = function (w, keystring)
    local symbol = nil
    local keys = {}
    for char in string.gmatch(keystring, ".") do
        if char == "<" then
            symbol = ""
        elseif char == ">" and symbol then
            if #symbol == 0 then
                table.insert(keys, "<")
                table.insert(keys, ">")
            else
                table.insert(keys, symbol)
            end
            symbol = nil
        elseif symbol == nil then
            table.insert(keys, char)
        else
            symbol = symbol .. char
        end
    end
    if symbol ~= nil then
        w:error("bad keystring: " .. keystring)
        return
    end
    for _, k in ipairs(keys) do
        if not w.win:send_key(key) then
            w:error("failed to send key: " .. k)
            return
        end
    end
end

