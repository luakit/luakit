--- lousy.bind library.
--
-- Key, buffer and command binding functions.
--
-- @module lousy.bind
-- @author Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local util = require("lousy.util")
local join = util.table.join
local keys = util.table.keys

local _M = {}

local function convert_bind_syntax(b)
    -- commands are a no-op
    if b:match("^:") and b ~= ":" then return b end
    -- Keys have sorted modifiers and uppercase -> lowercase+shift conversion
    if utf8.len(b) == 1 or b:match("^<.+>$") then
        b = b:match("^<(.+)>$") or b
        local mods = b == "-" and {"Minus"} or util.string.split(b, "%-")
        local key = table.remove(mods)
        -- Convert upper-case keys to shift+lower-case
        local lc = luakit.wch_lower(key)
        if lc ~= key then
            key = lc
            table.insert(mods, "Shift")
        end
        mods = _M.parse_mods(mods)
        return "<".. (mods and (mods.."-") or "") .. key .. ">"
    end
    -- Otherwise, make it a buffer bind; wrap in ^$ if necessary
    b = string.sub(b,1,1) == "^" and b or "^" .. b .. "$"
    if utf8.len(b) == 3 then
        local nb = convert_bind_syntax(b:sub(2,-2))
        msg.verbose("implicitly converting bind '%s' to '%s'", b, nb)
        b = nb
    end
    return b
end

local function convert_binds_table(binds)
    if binds.converted then return binds end
    local converted = { converted = true }
    for i, bind in ipairs(binds) do
        converted[i] =  { convert_bind_syntax(bind[1]), bind[2], bind[3] }
    end
    return converted
end

--- Set of modifiers to ignore.
-- @readwrite
_M.ignore_mask = {
    Mod2 = true, Mod3 = true, Mod5 = true, Lock = true,
}

--- A table that contains mappings for key names.
-- @readwrite
_M.map = {
    ISO_Left_Tab = "Tab",
    PgUp = "Page_Up",
    PgDn = "Page_Down",
    ["-"] = "Minus",
}

--- A table that contains mappings for modifier names.
-- @readwrite
_M.mod_map = {
    C = "Control",
    S = "Shift",
    Ctrl = "Control",
}

--- Parse a table of modifier keys into a string.
-- @tparam table mods The table of modifier keys.
-- @tparam[opt] boolean remove_shift Remove the shift key from the modifier
-- table.
-- @default `false`
-- @treturn string A string of key names, separated by hyphens (-).
function _M.parse_mods(mods, remove_shift)
    local t = {}
    local recognized_mods = { "shift", "lock", "control", "mod1", "mod2", "mod3", "mod4", "mod5" }
    for _, mod in ipairs(mods) do
        if not _M.ignore_mask[mod] then
            mod = string.lower(_M.mod_map[mod] or _M.map[mod] or mod)
            assert(util.table.hasitem(recognized_mods, mod), "unrecognized modifier '"..mod.."'")
            t[mod] = true
        end
    end

    -- For single character bindings shift is not processed as it should
    -- have already transformed the keycode within gdk.
    if remove_shift then t.shift = nil end

    mods = keys(t)
    table.sort(mods)
    mods = table.concat(mods, "-")
    return mods ~= "" and mods or nil
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
    binds = convert_binds_table(binds)
    for _, m in ipairs(binds) do
        local b, a, o = unpack(m)
        if b == "<any>" then
            if a.func(object, join(o, args), o) ~= false then
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
-- @tparam string mods The string of modifier keys.
-- @tparam string key The key name.
-- @tparam table args A table of arguments passed through to any key bindings
-- called.
-- @treturn boolean `true` if a key binding was ran successfully.
function _M.match_key(object, binds, mods, key, args)
    binds = convert_binds_table(binds)
    for _, m in ipairs(binds) do
        local b, a, o = unpack(m)
        if b == "<".. (mods and (mods.."-") or "") .. key .. ">" then
            if a.func(object, join(o, args), o) ~= false then
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
-- @tparam string mods The table of modifier keys.
-- @tparam string button The button name.
-- @tparam table args A table of arguments passed through to any button bindings
-- called.
-- @treturn boolean `true` if a key binding was ran successfully.
function _M.match_but(object, binds, mods, button, args)
    binds = convert_binds_table(binds)
    for _, m in ipairs(binds) do
        local b, a, o = unpack(m)
        if b == "<" .. (mods and (mods.."-") or "") .. "Mouse" .. button .. ">" then
            if a.func(object, join(o, args), o) ~= false then
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
    binds = convert_binds_table(binds)

    local has_partial_match = false
    for _, m in ipairs(binds) do
        local b, a, o = unpack(m)
        if b:match("^^") then
            if buffer:match(b) then
                local params = {join(o, args, { buffer = buffer }), o}
                if a.compat == "buffer" then table.insert(params, 1, buffer) end
                if a.func(object, unpack(params)) ~= false then
                    return true, true
                end
            end
            if is_partial_match(buffer, b) then
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
    binds = convert_binds_table(binds)

    -- The command is the first word in the buffer string
    local command  = string.match(buffer, "^(%S+)")
    -- And the argument is the entire string thereafter
    local argument = string.match(string.sub(buffer, #command + 1), "^%s+([^%s].*)$")

    -- Set args.cmd to tell buf/any binds they were called from match_cmd
    args = join(args or {}, {
        binds = binds,
        cmd = buffer,
        arg = argument,
    })

    for _, m in ipairs(binds) do
        local b, a, o = unpack(m)
        -- split command binding string into long and short forms
        local cmds = {}
        for _, cmd in ipairs(util.string.split(b:gsub("^:", ""), ",%s+:")) do
            if string.match(cmd, "^([%-%w]+)%[(%w+)%]") then
                local l, r = string.match(cmd, "^([%-%w]+)%[(%w+)%]")
                table.insert(cmds, l..r)
                table.insert(cmds, l)
            else
                table.insert(cmds, cmd)
            end
        end

        -- Command matching
        if b:match("^:") and util.table.hasitem(cmds, command) then
            local params = {join(o, args, { argument = argument }), o}
            if a.compat then table.insert(params, 1, argument) end
            if a.func(object, unpack(params)) ~= false then
                return true
            end
        -- Buffer matching
        elseif b:match("^%^") and string.match(buffer, b) then
            local params = {join(o, args, { buffer = buffer }), o}
            if a.compat then table.insert(params, 1, buffer) end
            if a.func(object, unpack(params)) ~= false then
                return true
            end
        -- Any matching
        elseif b == "<any>" then
            if a.func(object, join(o, args), o) ~= false then
                return true
            end
        end
    end
    return false
end

--- Attempt to match either a key or buffer binding and execute it. This
-- function is also responsible for performing operations on the buffer when
-- necessary and the buffer is enabled.
--
-- When matching key bindings, this function ignores the case of `key`, and uses
-- the presence of the Shift modifier to determine which bindings should be matched.
--
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
    binds = convert_binds_table(binds)

    if not key then return false end
    local len = utf8.len(key)

    -- Compile metadata table
    args = join(args or {}, {
        object = object,
        binds  = binds,
        mods   = mods,
        key    = key,
    })

    local omods = mods
    mods = _M.parse_mods(mods, type(key) == "string" and len == 1)

    if _M.match_any(object, binds, args) then
        return true

    -- Match button bindings
    elseif type(key) == "number" then
        return _M.match_but(object, binds, mods, key, args)

    -- Match key bindings
    elseif (not args.buffer or not args.enable_buffer) or mods or len ~= 1 then
        -- Remove tab for single-char keys with no case (like ?, :, etc)
        local lk = luakit.wch_lower(key)
        local remove_shift = lk == luakit.wch_upper(key) and len == 1
        local m = _M.parse_mods(omods, remove_shift)
        if _M.match_key(object, binds, m, lk, args) then
            return true
        end
    end

    -- -- Invert key case on capslock
    if util.table.hasitem(omods, "Lock") then
        local uc, lc = luakit.wch_upper(key), luakit.wch_lower(key)
        key = key == uc and lc or uc
        table.remove(omods, util.table.hasitem(omods, "Lock"))
    end
    mods = _M.parse_mods(omods, type(key) == "string" and len == 1)

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
    if b:match("^^") then
        if string.sub(b,1,1) .. string.sub(b, -1, -1) == "^$" then
            b = string.sub(b, 2, -2)
        end
        return b:gsub("%%([%^%$%(%)%%%.%[%]%*%+%-%?%)])", "%1")
    elseif b:match("^<.>$") then
        return b:sub(2,2)
    else
        return b
    end
end

--- Bind a trigger to an action, adding the resulting binding to an array of
-- bindings.
-- @tparam table binds The array of bindings to add the new binding to.
-- @tparam string bind The trigger that will activate the action associated with
-- this bind.
-- @tparam table action The action that will be activated.
-- @tparam[opt] table opts A table of bind-time options that will be passed to the
-- action when it is activated.
function _M.add_bind (binds, bind, action, opts)
    assert(binds and type(binds) == "table", "invalid binds table type: " .. type(binds))
    assert(bind and type(bind) == "string", "invalid bind type: " .. type(bind))
    assert(action and type(action) == "table", "invalid action type: " .. type(action))
    bind = convert_bind_syntax(bind)
    _M.remove_bind(binds, bind)
    table.insert(binds, { bind, action, opts or {} })
    msg.verbose("added bind %s", bind)
end

--- Remove any binding with a specific trigger from the given array of bindings.
-- @tparam table binds The array of bindings to remove the named binding from.
-- @tparam string bind The trigger to unbind.
-- @treturn table The associated action of the binding that was removed, or `nil` if
-- not found.
-- @treturn table The options of the binding that was removed, or `nil` if not found.
function _M.remove_bind (binds, bind)
    assert(binds and type(binds) == "table", "invalid binds table type: " .. type(binds))
    assert(bind and type(bind) == "string", "invalid bind type: " .. type(bind))
    bind = convert_bind_syntax(bind)
    for i, m in ipairs(binds) do
        if m[1] == bind then
            table.remove(binds, i)
            msg.verbose("removed bind %s", bind)
            return m[2], m[3]
        end
    end
    msg.verbose("no bind %s to remove", bind)
    return nil, nil
end

--- Remap a binding from a given trigger to a new trigger, optionally keeping
-- the original binding. In both cases, the new binding will have the same
-- options as the original binding.
-- @tparam table binds The array of bindings to remap within.
-- @tparam string new The new trigger to map from.
-- @tparam string old The existing trigger to remap.
-- @tparam[opt] boolean keep Retain the existing binding.
-- @default `false`
function _M.remap_bind (binds, new, old, keep)
    assert(binds and type(binds) == "table", "invalid binds table type: " .. type(binds))
    assert(new and type(new) == "string", "invalid bind type: " .. type(new))
    assert(old and type(old) == "string", "invalid bind type: " .. type(old))
    new = convert_bind_syntax(new)
    old = convert_bind_syntax(old)
    for _, m in ipairs(binds) do
        if m[1] == old then
            msg.verbose("remapping bind to %s, %s %s", new, keep and "keeping" or "removing", old)
            if keep then
                _M.add_bind(binds, new, m[2], m[3])
            else
                m[1] = new
            end
            return
        end
    end
    msg.verbose("no bind %s to remap", old)
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
