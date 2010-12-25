---------------------------------------------------------------------------
-- @author Mason Larobina &lt;mason.larobina@gmail.com&gt;
-- @copyright 2010 Mason Larobina
---------------------------------------------------------------------------

--- Grab environment we need
local assert = assert
local ipairs = ipairs
local pairs = pairs
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

--- A table that contains mappings for key names.
map = {
    ISO_Left_Tab = "Tab",
}

--- Return cloned, sorted & filtered modifier mask table.
-- @param mods The table of modifiers
-- @param remove_shift Remove Shift key from modifiers table (Normally done if
-- the key pressed is a single character)
-- @return Filtered modifiers table
function filter_mods(mods, remove_shift)
    -- Clone & sort new modifiers table
    mods = util.table.clone(mods)
    table.sort(mods)
    -- Filter out ignored modifiers
    mods = util.table.difference(mods, ignore_modifiers)
    if remove_shift then
        return util.table.difference(mods, {"Shift",})
    end
    return mods
end

--- Create new key binding.
-- @param mods Modifiers table.
-- @param key The key name.
-- @param func The callback function.
-- @param opts Optional binding and callback options/state/metadata.
-- @return A key binding struct.
function key(mods, key, func, opts)
    assert(type(mods) == "table", "invalid modifiers table")
    assert(type(key)  == "string" and #key > 0, "invalid key string")
    assert(type(func) == "function", "invalid callback function")

    return {
        type = "key",
        mods = filter_mods(mods, #key == 1), -- Remove Shift key for char keys
        key  = key,
        func = func,
        opts = opts or {},
    }
end

--- Create new button binding.
-- @param mods Modifiers table.
-- @param button The mouse button number.
-- @param func The callback function.
-- @param opts Optional binding and callback options/state/metadata.
-- @return A button binding struct.
function but(mods, button, func, opts)
    assert(type(mods) == "table", "invalid modifiers table")
    assert(type(button) == "number", "invalid button number")
    assert(type(func) == "function", "invalid callback function")

    return {
        type   = "button",
        mods   = filter_mods(mods), -- Sort modifiers
        button = button,
        func   = func,
        opts   = opts or {},
    }
end

--- Create new buffer binding.
-- @param pattern The pattern to match against the buffer.
-- @param func The callback function.
-- @param opts Optional binding and callback options/state/metadata.
-- @return A buffer binding struct.
function buf(pattern, func, opts)
    assert(type(pattern) == "string" and #pattern > 0, "invalid pattern string")
    assert(type(func) == "function", "invalid callback function")

    return {
        type    = "buffer",
        pattern = pattern,
        func    = func,
        opts    = opts or {},
    }
end

--- Create new command binding.
-- @param cmds A table of command names to match or "co[mmand]" string to parse.
-- @param func The callback function.
-- @param opts Optional binding and callback options/state/metadata.
-- @return A command binding struct.
function cmd(cmds, func, opts)
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
    assert(#cmds > 0, "empty commands table")
    assert(type(func) == "function", "invalid function type")

    return {
        type = "command",
        cmds = cmds,
        func = func,
        opts = opts or {},
    }
end

--- Create a binding which is always called.
-- @param func The callback function.
-- @param opts Optional binding and callback options/state/metadata.
-- opts table given when the bind was created.
function any(func, opts)
    assert(type(func) == "function", "invalid callback function")

    return {
        type = "any",
        func = func,
        opts = opts or {},
    }
end

--- Try and match an any binding.
-- @param object The first argument of the bind callback function.
-- @param binds The table of binds in which to check for a match.
-- @param args The bind options/state/metadata table which is applied over the
-- opts table given when the bind was created.
-- @return True if a binding was matched and called.
function match_any(object, binds, args)
    for _, b in ipairs(binds) do
        if b.type == "any" then
            if b.func(object, join(b.opts, args)) ~= false then
                return true
            end
        end
    end
end
--- Try and match a key binding in a given table of bindings and call that
-- bindings callback function.
-- @param object The first argument of the bind callback function.
-- @param binds The table of binds in which to check for a match.
-- @param mods The modifiers to match.
-- @param key The key name to match.
-- @param args The bind options/state/metadata table which is applied over the
-- opts table given when the bind was created.
-- @return True if a binding was matched and called.
function match_key(object, binds, mods, key, args)
    for _, b in ipairs(binds) do
        if b.type == "key" and b.key == key and util.table.isclone(b.mods, mods) then
            if b.func(object, join(b.opts, args)) ~= false then
                return true
            end
        end
    end
end

--- Try and match a button binding in a given table of bindings and call that
-- bindings callback function.
-- @param object The first argument of the bind callback function.
-- @param binds The table of binds in which to check for a match.
-- @param mods The modifiers to match.
-- @param button The mouse button number to match.
-- @param args The bind options/state/metadata table which is applied over the
-- opts table given when the bind was created.
-- @return True if a binding was matched and called.
function match_but(object, binds, mods, button, args)
    for _, b in ipairs(binds) do
        if b.type == "button" and b.button == button and util.table.isclone(b.mods, mods) then
            if b.func(object, join(b.opts, args)) ~= false then
                return true
            end
        end
    end
end

--- Try and match a buffer binding in a given table of bindings and call that
-- bindings callback function.
-- @param object The first argument of the bind callback function.
-- @param binds The table of binds in which to check for a match.
-- @param buffer The buffer string to match.
-- @param args The bind options/state/metadata table which is applied over the
-- opts table given when the bind was created.
-- @return True if a binding was matched and called.
function match_buf(object, binds, buffer, args)
    for _, b in ipairs(binds) do
        if b.type == "buffer" and string.match(buffer, b.pattern) then
            if b.func(object, buffer, join(b.opts, args)) ~= false then
                return true
            end
        --elseif b.type == "any" then
        --    if b.func(object, join(b.opts, args)) ~= false then
        --        return true
        --    end
        end
    end
end

--- Try and match a command or buffer binding in a given table of bindings
-- and call that bindings callback function.
-- @param object The first argument of the bind callback function.
-- @param binds The table of binds in which to check for a match.
-- @param buffer The buffer string to match.
-- @param args The bind options/state/metadata table which is applied over the
-- opts table given when the bind was created.
-- @return True if either type of binding was matched and called.
function match_cmd(object, binds, buffer, args)
    -- The command is the first word in the buffer string
    local command  = string.match(buffer, "^([^%s]+)")
    -- And the argument is the entire string thereafter
    local argument = string.match(string.sub(buffer, #command + 1), "^%s+([^%s].*)$")

    for _, b in ipairs(binds) do
        -- Command matching
        if b.type == "command" and util.table.hasitem(b.cmds, command) then
            if b.func(object, argument, join(b.opts, args)) ~= false then
                return true
            end
        -- Buffer matching
        elseif b.type == "buffer" and string.match(buffer, b.pattern) then
            if b.func(object, buffer, join(b.opts, args)) ~= false then
                return true
            end
        -- Any matching
        --elseif b.type == "any" then
        --    if b.func(object, join(b.opts, args)) ~= false then
        --        return true
        --    end
        end
    end
end

--- Attempt to match either a key or buffer binding and execute it. This
-- function is also responsible for performing operations on the buffer when
-- necessary and the buffer is enabled.
-- @param object The first argument of the bind callback function.
-- @param binds The table of binds in which to check for a match.
-- @param mods The modifiers to match.
-- @param key The key name to match.
-- @param args The bind options/state/metadata table which is applied over the
-- opts table given when the bind was created.
-- @return True if a key or buffer binding was matched or if a key was added to
-- the buffer.
-- @return The new buffer truncated to 10 characters (if you need more buffer
-- then use the input bar for whatever you are doing).
function hit(object, binds, mods, key, args)
    -- Convert keys using map
    key = map[key] or key

    -- Filter modifers table
    mods = filter_mods(mods, type(key) == "string" and #key == 1)

    -- Compile metadata table
    args = join(args or {}, {
        object = object,
        binds  = binds,
        mods   = mods,
        key    = key,
    })

    if match_any(object, binds, args) then
        return true

    -- Match button bindings
    elseif type(key) == "number" then
        if match_but(object, binds, mods, key, args) then
            return true
        end
        return false

    -- Match key bindings
    elseif (not args.buffer or not args.enable_buffer) or #mods ~= 0 or #key ~= 1 then
        -- Check if the current buffer affects key bind (I.e. if the key has a
        -- `[count]` prefix)
        if match_key(object, binds, mods, key, args) then
            return true
        end
    end

    -- Clear buffer
    if not args.enable_buffer or #mods ~= 0 then
        return false

    -- Else match buffer
    elseif #key == 1 then
        if not args.updated_buf then
            args.buffer = (args.buffer or "") .. key
            args.updated_buf = true
        end
        if match_buf(object, binds, args.buffer, args) then
            return true
        end
    end

    -- Return buffer if valid
    if args.buffer then
        return false, string.sub(args.buffer, 1, 10)
    end
    return false
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
