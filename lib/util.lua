---------------------------------------------------------------------------
-- Copyright Julien Danjou <julien@danjou.info> 2008
-- Copyright Mason Larobina <mason.larobina@gmail.com> 2010
---------------------------------------------------------------------------

-- Grab environment we need
local assert = assert
local debug = debug
local error = error
local io = io
local ipairs = ipairs
local os = os
local pairs = pairs
local pairs = pairs
local print = print
local rstring = string
local rtable = table
local type = type
local capi = { luakit = luakit }

-- Utility module for luakit
module("util")

table = {}
string = {}

local xml_entity_names = { ["'"] = "&apos;", ["\""] = "&quot;", ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" };
-- Escape a string from XML char.
function escape(text)
    return text and text:gsub("['&<>\"]", xml_entity_names) or nil
end

local xml_entity_chars = { lt = "<", gt = ">", nbsp = " ", quot = "\"", apos = "'", ndash = "-", mdash = "-", amp = "&" };
-- Unescape a string from entities.
function unescape(text)
    return text and text:gsub("&(%a+);", xml_entity_chars) or nil
end

-- Return the difference of another table as a new table.
-- (I.e. all elements in the first table but not in the other)
function table.difference(t, other)
    local ret = {}
    for k, v in pairs(t) do
        if type(k) == "number" then
            local found = false
            for _, ov in ipairs(other) do
                if ov == v then
                    found = true
                    break
                end
            end
            if not found then rtable.insert(ret, v) end
        else
            if not other[k] then ret[k] = v end
        end
    end
    return ret
end

-- Join all tables given as parameters.
-- This will iterate all tables and insert all their keys into a new table.
function table.join(...)
    local ret = {}
    for i = 1, arg.n do
        if arg[i] then
            for k, v in pairs(arg[i]) do
                if type(k) == "number" then
                    rtable.insert(ret, v)
                else
                    ret[k] = v
                end
            end
        end
    end
    return ret
end

-- Check if a table has an item and return its key.
function table.hasitem(t, item)
    for k, v in pairs(t) do
        if v == item then
            return k
        end
    end
end

-- Get a sorted table with all integer keys from a table
function table.keys(t)
    local keys = { }
    for k, _ in pairs(t) do
        rtable.insert(keys, k)
    end
    rtable.sort(keys, function (a, b)
        return type(a) == type(b) and a < b or false
    end)
    return keys
end

-- Reverse a table
function table.reverse(t)
    local tr = { }
    -- reverse all elements with integer keys
    for _, v in ipairs(t) do
        rtable.insert(tr, 1, v)
    end
    -- add the remaining elements
    for k, v in pairs(t) do
        if type(k) ~= "number" then
            tr[k] = v
        end
    end
    return tr
end

-- Clone a table
function table.clone(t)
    local c = { }
    for k, v in pairs(t) do
        c[k] = v
    end
    return c
end

-- Return true if table `b` is identical to table `a`
function table.isclone(a, b)
    if #a ~= #b then return false end
    for k, v in pairs(a) do
        if a[k] ~= b[k] then return false end
    end
    return true
end

-- Remove an element at a given position (or key) in a table and return the
-- value that was in that position.
function table.pop(t, k)
    local v = t[k]
    if type(k) == "number" then
        table.remove(t, k)
    else
        t[k] = nil
    end
    return v
end

-- Check if a file exists
function os.exists(f)
    fh, err = io.open(f)
    if fh then
        fh:close()
        return true
    end
end

-- Python like string split (source: lua wiki)
function string.split(s, pattern, ret)
    if not pattern then pattern = "%s+" end
    if not ret then ret = {} end
    local pos = 1
    local fstart, fend = rstring.find(s, pattern, pos)
    while fstart do
        rtable.insert(ret, rstring.sub(s, pos, fstart - 1))
        pos = fend + 1
        fstart, fend = rstring.find(s, pattern, pos)
    end
    rtable.insert(ret, rstring.sub(s, pos))
    return ret
end

-- Search locally, xdg home path and then luakit install path for a given file
local function xdg_find(f, xdg_home_path)
    -- Ignore absolute paths
    if rstring.match(f, "^/") then
        if os.exists(f) then return f end
        error(rstring.format("xdg_find: No such file: %s\n", f))
    end

    -- Check if file exists at the following locations & return first match
    local paths = { f, xdg_home_path .. "/" .. f, capi.luakit.install_path .. "/" .. f }
    for _, p in ipairs(paths) do
        if os.exists(p) then return p end
    end

    error(rstring.format("xdg_find: No such file at:\n\t%s\n", rtable.concat(paths, ",\n\t")))
end

function find_config(f) return xdg_find(f, capi.luakit.config_dir) end
function find_data(f)   return xdg_find(f, capi.luakit.data_dir)   end
function find_cache(f)  return xdg_find(f, capi.luakit.cache_dir)  end

-- vim: ft=lua:et:sw=4:ts=8:sts=4:tw=80
