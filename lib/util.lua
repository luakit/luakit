---------------------------------------------------------------------------
-- Copyright Julien Danjou <julien@danjou.info> 2008
-- Copyright Mason Larobina <mason.larobina@gmail.com> 2010
---------------------------------------------------------------------------

-- Grab environment we need
local assert = assert
local debug = debug
local io = io
local ipairs = ipairs
local os = os
local pairs = pairs
local pairs = pairs
local rtable = table
local string = string
local type = type
local print = print

-- Utility module for awful
module("util")

table = {}

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

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:encoding=utf-8:textwidth=80
