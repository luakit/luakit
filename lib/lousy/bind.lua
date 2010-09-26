---------------------------------------------------------------------------
-- @author Mason Larobina &lt;mason.larobina@gmail.com&gt;
-- @copyright 2010 Mason Larobina
---------------------------------------------------------------------------

--- Grab environment we need
local assert = assert
local ipairs = ipairs
local pairs = pairs
local print = print
local setmetatable = setmetatable
local string = string
local table = table
local type = type
local unpack = unpack
local util = require("lousy.util")
local join = util.table.join

--- Key, buffer and command binding functions.
module("lousy.bind")

-- Modifiers to ignore
ignore_modifiers = { "Mod2", "Mod3", "Mod5", "Lock" }

--- A table that contains mappings for key conversion.
map = {
    ISO_Left_Tab = "Tab",
}

--- Return cloned, sorted & filtered modifier mask table.
-- @param mods The table of modifiers
-- @param remove_shift Remove Shift key from modifiers table (Normally done if
-- the key pressed is a single character)
-- @return Filtered modifiers table
function filter_mods(mods, remove_shift)
    assert(type(mods) == "table", "invalid modifiers table type")
    -- Clone & sort new modifiers table
    local mods = util.table.clone(mods)
    table.sort(mods)
    -- Filter out ignored modifiers
    mods = util.table.difference(mods, ignore_modifiers)
    if remove_shift then return util.table.difference(mods, {"Shift",}) end
    return mods
end

--- Create new key binding.
-- @param mods Modifiers table.
-- @param key The key name.
-- @param func The callback function.
-- @param meta Optional binding and callback options/state/metadata.
-- @return A key binding struct.
function key(mods, key, func, meta)
    assert(type(key)  == "string",   "invalid key type")
    assert(#key > 0,                 "empty key string")
    assert(type(func) == "function", "invalid function type")
    local mods = filter_mods(mods, #key == 1)
    return { mods = mods, key = key, func = func, meta = (meta or {}) }
end

--- Create new button binding.
-- @param mods Modifiers table.
-- @param button The mouse button number.
-- @param func The callback function.
-- @param meta Optional binding and callback options/state/metadata.
-- @return A button binding struct.
function but(mods, button, func, meta)
    assert(type(button) == "number",   "invalid button type")
    assert(type(func)   == "function", "invalid function type")
    local mods = filter_mods(mods, false)
    return { mods = mods, button = button, func = func, meta = (meta or {}) }
end

--- Create new buffer binding.
-- @param pattern The pattern to match against the buffer.
-- @param func The callback function.
-- @param meta Optional binding and callback options/state/metadata.
-- @return A buffer binding struct.
function buf(pattern, func, meta)
    assert(type(pattern) == "string",   "invalid pattern type")
    assert(#pattern > 0,                "empty pattern string")
    assert(type(func)    == "function", "invalid function type")
    return { pattern = pattern, func = func, meta = (meta or {}) }
end

--- Create new command binding.
-- @param cmds A table of command names to match or "co[mmand]" string to parse.
-- @param func The callback function.
-- @param meta Optional binding and callback options/state/metadata.
-- @return A command binding struct.
function cmd(cmds, func, meta)
    -- Parse "co[mmand]" or literal.
    if type(cmds) == "string" then
        if string.match(cmds, "^(%w+)%[(%w+)%]") then
            local l, r = string.match(cmds, "^(%w+)%[(%w+)%]")
            cmds = {l..r, l}
        else
            cmds = {cmds,}
        end
    end

    assert(type(cmds) == "table", "invalid commands table type")
    assert(#cmds > 0,             "empty commands table")
    assert(type(func) == "function",  "invalid function type")
    return { cmds = cmds, func = func, meta = (meta or {}) }
end

--- Try and match a key binding in a given table of bindings and call that
-- bindings callback function.
-- @param binds The table of binds in which to check for a match.
-- @param mods The modifiers to match.
-- @param key The key name to match.
-- @param arg The first argument of the callback function.
-- @param meta The bind options/state/metadata table which is applied over the
-- meta table given when the bind was created.
-- @return True if a binding was matched and called.
function match_key(binds, mods, key, arg, meta)
    for _, b in ipairs(binds) do
        if b.key == key and util.table.isclone(b.mods, mods) then
            if b.func(arg, join(b.meta, meta)) ~= false then return true end
        end
    end
end

--- Try and match a button binding in a given table of bindings and call that
-- bindings callback function.
-- @param binds The table of binds in which to check for a match.
-- @param mods The modifiers to match.
-- @param button The mouse button number to match.
-- @param arg The first argument of the callback function.
-- @param meta The bind options/state/metadata table which is applied over the
-- meta table given when the bind was created.
-- @return True if a binding was matched and called.
function match_button(binds, mods, button, arg, meta)
    for _, b in ipairs(binds) do
        if b.button == button and util.table.isclone(b.mods, mods) then
            if b.func(arg, join(b.meta, meta)) ~= false then return true end
        end
    end
end

--- Try and match a buffer binding in a given table of bindings and call that
-- bindings callback function.
-- @param binds The table of binds in which to check for a match.
-- @param buffer The buffer string to match.
-- @param arg The first argument of the callback function.
-- @param meta The bind options/state/metadata table which is applied over the
-- meta table given when the bind was created.
-- @return True if a binding was matched and called.
function match_buf(binds, buffer, arg, meta)
    for _, b in ipairs(binds) do
        if b.pattern and string.match(buffer, b.pattern) then
            if b.func(arg, buffer, join(b.meta, meta)) ~= false then return true end
        end
    end
end

--- Try and match a command or buffer binding in a given table of bindings
-- and call that bindings callback function.
-- @param binds The table of binds in which to check for a match.
-- @param buffer The buffer string to match.
-- @param arg The first argument of the callback function.
-- @param meta The bind options/state/metadata table which is applied over the
-- meta table given when the bind was created.
-- @return True if either type of binding was matched and called.
function match_cmd(binds, buffer, arg, meta)
    -- The command is the first word in the buffer string
    local command  = string.match(buffer, "^([^%s]+)")
    -- And the argument is the entire string thereafter
    local argument = string.match(string.sub(buffer, #command + 1), "^%s+([^%s].*)$")

    for _, b in ipairs(binds) do
        -- Command matching
        if b.cmds and util.table.hasitem(b.cmds, command) then
            if b.func(arg, argument, join(b.meta, meta)) ~= false then return true end
        -- Buffer matching
        elseif b.pattern and string.match(buffer, b.pattern) then
            if b.func(arg, buffer, join(b.meta, meta)) ~= false then return true end
        end
    end
end

--- Attempt to match either a key or buffer binding and execute it. This
-- function is also responsible for performing operations on the buffer when
-- necessary and the buffer is enabled.
-- @param binds The table of binds in which to check for a match.
-- @param mods The modifiers to match.
-- @param key The key name to match.
-- @param buffer The current buffer string.
-- @param enable_buffer Is the buffer enabled? If not the returned buffer will
-- be nil and no buffer binds will be matched.
-- @param arg The first argument of the child callback function.
-- @param meta The bind options/state/metadata table which is applied over the
-- meta table given when the bind was created.
-- @return True if a key or buffer binding was matched or if a key was added to
-- the buffer.
-- @return The new buffer truncated to 10 characters (if you need more buffer
-- then use the input bar for whatever you are doing).
function hit(binds, mods, key, buffer, enable_buffer, arg, meta)
    -- Convert keys using map
    key = map[key] or key

    -- Compile metadata table
    meta = join(meta or {}, { binds = binds, mods = mods, key = key })

    -- Filter modifers table
    local mods = filter_mods(mods, type(key) == "string" and #key == 1)

    -- Match button bindings
    if type(key) == "number" then
        return match_button(binds, mods, key, arg, meta)

    -- Match key bindings
    elseif (not buffer or not enable_buffer) or #mods ~= 0 or #key ~= 1 then
        if match_key(binds, mods, key, arg, meta) then
            return true
        end
    end

    -- Clear buffer
    if not enable_buffer or #mods ~= 0 then
        return false

    -- Match buffer
    elseif #key == 1 then
        buffer = (buffer or "") .. key
        if match_buf(binds, buffer, arg, meta) then
            return true
        end
    end

    -- Return buffer if valid
    if buffer then
        return true, buffer:sub(1, 10)
    end
    return true
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
