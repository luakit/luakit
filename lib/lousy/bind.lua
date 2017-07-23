--- lousy.bind library.
--
-- Key, buffer and command binding functions.
--
-- @module lousy.bind
-- @author Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2010 Mason Larobina

local util = require("lousy.util")
local join = util.table.join
local keys = util.table.keys

local _M = {}

--- Set of modifiers to ignore.
-- @readwrite
_M.ignore_mask = {
    Mod2 = true, Mod3 = true, Mod5 = true, Lock = true,
}

--- A table that contains mappings for key names.
-- @readwrite
_M.map = {
    ISO_Left_Tab = "Tab",
}

--- Parse a table of modifier keys into a string.
-- @tparam table mods The table of modifier keys.
-- @tparam[opt] boolean remove_shift Remove the shift key from the modifier
-- table.
-- @default `false`
-- @treturn string A string of key names, separated by hyphens (-).
function _M.parse_mods(mods, remove_shift)
    local t = {}
    for _, mod in ipairs(mods) do
        if not _M.ignore_mask[mod] then
            mod = _M.map[mod] or mod
            t[mod] = true
        end
    end

    -- For single character bindings shift is not processed as it should
    -- have already transformed the keycode within gdk.
    if remove_shift then t.Shift = nil end

    mods = table.concat(keys(t), "-")
    return mods ~= "" and mods or nil
end

--- Create a new key binding.
-- @tparam table mods The table of modifier keys.
-- @tparam string key The key name.
-- @tparam[opt] string desc A description for this key binding.
-- @default `nil`
-- @tparam function func The callback function for this key binding.
-- @tparam[opt] table opts The table of key binding options.
-- @default `{}`
-- @treturn table A table representing the new key binding.
function _M.key(mods, key, desc, func, opts)
    -- Detect optional description & adjust argument positions
    if type(desc) == "function" then
        desc, func, opts = nil, desc, func
    end

    assert(type(mods) == "table", "invalid modifiers table")
    assert(type(key)  == "string" and #key > 0, "invalid key string")
    assert(not desc or type(desc) == "string", "invalid description")
    assert(type(func) == "function", "invalid callback function")

    return {
        type = "key",
        mods = _M.parse_mods(mods, string.wlen(key) == 1),
        key  = key,
        desc = desc,
        func = func,
        opts = opts or {},
    }
end

--- Create a new button binding.
-- @tparam table mods The table of modifier keys.
-- @tparam string button The button name.
-- @tparam[opt] string desc A description for this button binding.
-- @tparam function func The callback function for this button binding.
-- @tparam[opt] table opts The table of button binding options.
-- @treturn table A table representing the new button binding.
function _M.but(mods, button, desc, func, opts)
    -- Detect optional description & adjust argument positions
    if type(desc) == "function" then
        desc, func, opts = nil, desc, func
    end

    assert(type(mods) == "table", "invalid modifiers table")
    assert(type(button) == "number", "invalid button number")
    assert(not desc or type(desc) == "string", "invalid description")
    assert(type(func) == "function", "invalid callback function")

    return {
        type   = "button",
        mods   = _M.parse_mods(mods),
        button = button,
        desc   = desc,
        func   = func,
        opts   = opts or {},
    }
end

--- Create a new buffer binding.
-- @tparam string pattern The text pattern to match.
-- @tparam[opt] string desc A description for this buffer binding.
-- @tparam function func The callback function for this buffer binding.
-- @tparam[opt] table opts The table of buffer binding options.
-- @treturn table A table representing the new buffer binding.
function _M.buf(pattern, desc, func, opts)
    -- Detect optional description & adjust argument positions
    if type(desc) == "function" then
        desc, func, opts = nil, desc, func
    end

    assert(type(pattern) == "string" and #pattern > 0, "invalid pattern string")
    assert(not desc or type(desc) == "string", "invalid description")
    assert(type(func) == "function", "invalid callback function")

    return {
        type    = "buffer",
        pattern = pattern,
        desc    = desc,
        func    = func,
        opts    = opts or {},
    }
end

--- Create a new command binding.
-- @tparam string|table cmds One or more text patterns to match.
-- @tparam[opt] string desc A description for this buffer binding.
-- @tparam function func The callback function for this buffer binding.
-- @tparam[opt] table opts The table of buffer binding options.
-- @treturn table A table representing the new buffer binding.
function _M.cmd(cmds, desc, func, opts)
    -- Detect optional description & adjust argument positions
    if type(desc) == "function" then
        desc, func, opts = nil, desc, func
    end

    -- Parse "co[mmand]" or literal.
    if type(cmds) == "string" then
        if string.match(cmds, "^([%-%w]+)%[(%w+)%]") then
            local l, r = string.match(cmds, "^([%-%w]+)%[(%w+)%]")
            cmds = {l..r, l}
        else
            cmds = {cmds,}
        end
    end

    assert(type(cmds) == "table", "invalid commands table type")
    assert(#cmds > 0, "empty commands table")
    assert(not desc or type(desc) == "string", "invalid description")
    assert(type(func) == "function", "invalid callback function")

    return {
        type = "command",
        cmds = cmds,
        desc = desc,
        func = func,
        opts = opts or {},
    }
end

--- Create a binding which is always called.
-- @tparam[opt] string desc A description for this binding.
-- @tparam function func The callback function for this binding.
-- @tparam[opt] table opts The table of binding options.
-- @treturn table A table representing the new binding.
function _M.any(desc, func, opts)
    -- Detect optional description & adjust argument positions
    if type(desc) == "function" then
        desc, func, opts = nil, desc, func
    end

    assert(not desc or type(desc) == "string", "invalid description")
    assert(type(func) == "function", "invalid callback function")

    return {
        type = "any",
        func = func,
        desc = desc,
        opts = opts or {},
    }
end

--- Match any 'any' bindings in a given table of bindings.
--
-- The bindings' callback functions are called in the order that they
-- occur in the given table of bindings. If any callback function
-- returns a value other than `false`, then matching stops and this
-- function immediately returns `true`. Otherwise, if the callback
-- returns `false`, matching continues.
--
-- @param object An object passed through to any 'any' bindings called.
-- @tparam table binds A table of bindings to search.
-- @tparam table args A table of arguments passed through to any 'any' bindings
-- called.
-- @treturn boolean `true` if an 'any' binding was ran successfully.
function _M.match_any(object, binds, args)
    for _, b in ipairs(binds) do
        if b.type == "any" then
            if b.func(object, join(b.opts, args)) ~= false then
                return true
            end
        end
    end
    return false
end

--- Match any key binding in a given table of bindings.
--
-- The bindings' callback functions are called in the order that they
-- occur in the given table of bindings. If any callback function
-- returns a value other than `false`, then matching stops and this
-- function immediately returns `true`. Otherwise, if the callback
-- returns `false`, matching continues.
--
-- @param object An object passed through to any key bindings called.
-- @tparam table binds A table of bindings to search.
-- @tparam table mods The table of modifier keys.
-- @tparam string key The key name.
-- @tparam table args A table of arguments passed through to any key bindings
-- called.
-- @treturn boolean `true` if a key binding was ran successfully.
function _M.match_key(object, binds, mods, key, args)
    for _, b in ipairs(binds) do
        if b.type == "key" and b.key == key and b.mods == mods then
            if b.func(object, join(b.opts, args)) ~= false then
                return true
            end
        end
    end
    return false
end

--- Match any button binding in a given table of bindings.
--
-- The bindings' callback functions are called in the order that they
-- occur in the given table of bindings. If any callback function
-- returns a value other than `false`, then matching stops and this
-- function immediately returns `true`. Otherwise, if the callback
-- returns `false`, matching continues.
--
-- @param object An object passed through to any key bindings called.
-- @tparam table binds A table of bindings to search.
-- @tparam table mods The table of modifier keys.
-- @tparam string button The button name.
-- @tparam table args A table of arguments passed through to any button bindings
-- called.
-- @treturn boolean `true` if a key binding was ran successfully.
function _M.match_but(object, binds, mods, button, args)
    for _, b in ipairs(binds) do
        if b.type == "button" and b.button == button and b.mods == mods then
            if b.func(object, join(b.opts, args)) ~= false then
                return true
            end
        end
    end
    return false
end

--- Determine if a string is a partial match for a Lua pattern
-- Only a restricted subset of patterns are allowed; it's assumed the
-- pattern should match the entire string (^$ is implied) and *+? are not
-- permitted.
-- @tparam string str The possible partial match
-- @tparam string pat The pattern to match against
local function is_partial_match(str, pat)
    -- Strip off any numerical prefix to the buffer; allows count syntax to work
    str = str:match("^%d*(%D.*)$") or ""
    if str == "" then return true end

    pat = pat:match("^%^?(.+)%$?$")
    local first_char_pat = pat:match("^(%[[^%]]+%])") or pat:match("^(%%.)") or pat:sub(1,1)
    local remainder = pat:sub(first_char_pat:len()+1)
    assert(not remainder:match("^[%+%*%?]"), "+*? not supported!")

    if not str:sub(1,1):find("^" .. first_char_pat) then
        return false
    else
        return is_partial_match(str:sub(2), remainder)
    end
end

--- Try and match a buffer binding in a given table of bindings and call that
-- bindings callback function.
-- @param object The first argument of the bind callback function.
-- @tparam table binds The table of binds in which to check for a match.
-- @tparam string buffer The buffer string to match.
-- @tparam table args The bind options/state/metadata table which is applied over the
-- opts table given when the bind was created.
-- @treturn boolean `true` if a binding was matched and called.
-- @treturn boolean `true` if a partial match exists.
function _M.match_buf(object, binds, buffer, args)
    assert(buffer and string.match(buffer, "%S"), "invalid buffer")

    local has_partial_match = false
    for _, b in ipairs(binds) do
        if b.type == "buffer" and string.match(buffer, b.pattern) then
            if b.func(object, buffer, join(b.opts, args)) ~= false then
                return true, true
            end
        --elseif b.type == "any" then
        --    if b.func(object, join(b.opts, args)) ~= false then
        --        return true
        --    end
        end
        if b.type == "buffer" then
            if is_partial_match(buffer, b.pattern) then
                has_partial_match = true
            end
        end
    end
    return false, has_partial_match
end

--- Try and match a command or buffer binding in a given table of bindings
-- and call that bindings callback function.
-- @param object The first argument of the bind callback function.
-- @tparam table binds The table of binds in which to check for a match.
-- @tparam string buffer The buffer string to match.
-- @tparam table args The bind options/state/metadata table which is applied over the
-- opts table given when the bind was created.
-- @treturn boolean `true` if either type of binding was matched and called.
function _M.match_cmd(object, binds, buffer, args)
    assert(buffer and string.match(buffer, "%S"), "invalid buffer")

    -- The command is the first word in the buffer string
    local command  = string.match(buffer, "^(%S+)")
    -- And the argument is the entire string thereafter
    local argument = string.match(string.sub(buffer, #command + 1), "^%s+([^%s].*)$")

    -- Set args.cmd to tell buf/any binds they were called from match_cmd
    args = join(args or {}, {
        binds = binds,
        cmd = buffer,
    })

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
        elseif b.type == "any" then
            if b.func(object, join(b.opts, args)) ~= false then
                return true
            end
        end
    end
    return false
end

--- Attempt to match either a key or buffer binding and execute it. This
-- function is also responsible for performing operations on the buffer when
-- necessary and the buffer is enabled.
-- @param object The first argument of the bind callback function.
-- @tparam table binds The table of binds in which to check for a match.
-- @tparam {string} mods The modifiers to match.
-- @tparam string key The key name to match.
-- @tparam table args The bind options/state/metadata table which is applied over the
-- opts table given when the bind was created.
-- @treturn boolean `true` if a key or buffer binding was matched or if a key was added to
-- the buffer.
-- @treturn string The new buffer truncated to 10 characters (if you need more buffer
-- then use the input bar for whatever you are doing). If no buffer binding
-- could be matched, the returned buffer will be the empty string.
function _M.hit(object, binds, mods, key, args)
    -- Convert keys using map
    key = _M.map[key] or key

    if not key then return false end
    local len = string.wlen(key)

    -- Compile metadata table
    args = join(args or {}, {
        object = object,
        binds  = binds,
        mods   = mods,
        key    = key,
    })

    mods = _M.parse_mods(mods, type(key) == "string" and len == 1)

    if _M.match_any(object, binds, args) then
        return true

    -- Match button bindings
    elseif type(key) == "number" then
        if _M.match_but(object, binds, mods, key, args) then
            return true
        end
        return false

    -- Match key bindings
    elseif (not args.buffer or not args.enable_buffer) or mods or len ~= 1 then
        -- Check if the current buffer affects key bind (I.e. if the key has a
        -- `[count]` prefix)
        if _M.match_key(object, binds, mods, key, args) then
            return true
        end
    end

    -- Clear buffer
    if not args.enable_buffer or mods then
        return false

    -- Else match buffer
    elseif len == 1 then
        if not args.updated_buf then
            args.buffer = (args.buffer or "") .. key
            args.updated_buf = true
        end
        local matched, partial = _M.match_buf(object, binds, args.buffer, args)
        if matched then
            return true
        end
        -- If no partial match, clear the buffer
        if not partial then
            args.buffer = nil
        end
    end

    -- Return buffer if valid
    if args.buffer then
        return false, string.sub(args.buffer, 1, 10)
    end
    return false
end

--- Produce a string describing the action that triggers a given binding.
-- For example, a binding for the down-arrow key would produce `"<Down>"`.
--
-- @tparam table b The binding.
-- @treturn string The binding description string.
function _M.bind_to_string(b)
    local t = b.type
    local m = b.mods

    if t == "key" then
        if m or string.wlen(b.key) > 1 then
            return "<".. (m and (m.."-") or "") .. b.key .. ">"
        else
            return b.key
        end
    elseif t == "buffer" then
        local p = b.pattern
        if string.sub(p,1,1) .. string.sub(p, -1, -1) == "^$" then
            p = string.sub(p, 2, -2)
        end
        p = p:gsub("%%([%^%$%(%)%%%.%[%]%*%+%-%?%)])", "%1")
        return p
    elseif t == "button" then
        return "<" .. (m and (m.."-") or "") .. "Mouse" .. b.button .. ">"
    elseif t == "any" then
        return "any"
    elseif t == "command" then
        local cmds = {}
        for i, cmd in ipairs(b.cmds) do
            cmds[i] = ":"..cmd
        end
        return table.concat(cmds, ", ")
    end
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
