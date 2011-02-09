---------------------------------------------------------------------------
-- @author Mason Larobina &lt;mason.larobina@gmail.com&gt;
-- @author Julien Danjou &lt;julien@danjou.info&gt;
-- @copyright 2010 Mason Larobina, 2008 Julien Danjou
---------------------------------------------------------------------------

--- Grab environment we need
local assert = assert
local debug = debug
local error = error
local io = io
local ipairs = ipairs
local loadstring = loadstring
local os = os
local pairs = pairs
local rstring = string
local rtable = table
local type = type
local tonumber = tonumber
local tostring = tostring
local math = require "math"
local capi = { luakit = luakit }

--- Utility functions for lousy.
module("lousy.util")

table = {}
string = {}

local xml_entity_names = { ["'"] = "&apos;", ["\""] = "&quot;", ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" };
local xml_entity_chars = { lt = "<", gt = ">", nbsp = " ", quot = "\"", apos = "'", ndash = "-", mdash = "-", amp = "&" };

--- Escape a string from XML characters.
-- @param text The text to escape.
-- @return A string with all XML characters escaped.
function escape(text)
    return text and text:gsub("['&<>\"]", xml_entity_names) or nil
end

--- Unescape a string from XML entities.
-- @param text The text to un-escape.
-- @return A string with all the XML entities un-escaped.
function unescape(text)
    return text and text:gsub("&(%a+);", xml_entity_chars) or nil
end

--- Create a directory
-- @param dir The directory.
-- @return mkdir return code
function mkdir(dir)
    return os.execute("mkdir -p " .. dir)
end

--- Eval Lua code.
-- @return The return value of Lua code.
function eval(s)
    return assert(loadstring(s))()
end

--- Check if a file is a Lua valid file.
-- This is done by loading the content and compiling it with loadfile().
-- @param path The file path.
-- @return A function if everything is alright, a string with the error
-- otherwise.
function checkfile(path)
    local f, e = loadfile(path)
    -- Return function if function, otherwise return error.
    if f then return f end
    return e
end

--- Return the difference of one table against another.
-- @param t The original table.
-- @param other The table to perform the difference against.
-- @return All elements in the first table that are not in the other table.
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

--- Join all tables given as parameters.
-- This will iterate all tables and insert all their keys into a new table.
-- @param args A list of tables to join
-- @return A new table containing all keys from the arguments.
function table.join(...)
    local ret = {}
    for _, t in pairs({...}) do
        for k, v in pairs(t) do
            if type(k) == "number" then
                rtable.insert(ret, v)
            else
                ret[k] = v
            end
        end
    end
    return ret
end

--- Check if a table has an item and return its key.
-- @param t The table.
-- @param item The item to look for in values of the table.
-- @return The key were the item is found, or nil if not found.
function table.hasitem(t, item)
    for k, v in pairs(t) do
        if v == item then
            return k
        end
    end
end

--- Get a sorted table with all integer keys from a table
-- @param t the table for which the keys to get
-- @return A table with keys
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

--- Reverse a table
-- @param t the table to reverse
-- @return the reversed table
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

--- Clone a table
-- @param t the table to clone
-- @return a clone of t
function table.clone(t)
    local c = { }
    for k, v in pairs(t) do
        c[k] = v
    end
    return c
end

--- Check if two tables are identical.
-- @param a The first table.
-- @param b The second table.
-- @return True if both tables are identical.
function table.isclone(a, b)
    if #a ~= #b then return false end
    for k, v in pairs(a) do
        if a[k] ~= b[k] then return false end
    end
    return true
end

--- Check if a file exists and is readable.
-- @param f The file path.
-- @return True if the file exists and is readable.
function os.exists(f)
    fh, err = io.open(f)
    if fh then
        fh:close()
        return true
    end
end

--- Python like string split (source: lua wiki)
-- @param s The string to split.
-- @param pattern The split pattern (I.e. "%s+" to split text by one or more
-- whitespace characters).
-- @param ret The table to insert the split items in to or a new table if nil.
-- @return A table of the string split by the pattern.
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

-- Python like string strip.
-- @param s The string to strip.
-- @param pattern The pattern to strip from the left-most and right-most of the
-- string.
-- @return The inner string segment.
function string.strip(s, pattern)
    local p = pattern or "%s*"
    local sub_start, sub_end

    -- Find start point
    local _, f_end = rstring.find(s, "^"..p)
    if f_end then sub_start = f_end + 1 end

    -- Find end point
    local f_start = rstring.find(s, p.."$")
    if f_start then sub_end = f_start - 1 end

    return rstring.sub(s, sub_start or 1, sub_end or #s)
end

local function find_file(paths)
    for _, p in ipairs(paths) do
        if os.exists(p) then return p end
    end
    return error(rstring.format("No such file at: \n\t%s\n", rtable.concat(paths, ",\n\t")))
end

--- Search and return the filepath of a file in the current working directory,
-- or $XDG_CONFIG_HOME/luakit/ or /etc/xdg/luakit/.
-- @param f The relative filepath.
-- @return The first valid filepath or an error.
function find_config(f)
    if rstring.match(f, "^/") then return f end
    -- Search locations
    local paths = { "config/"..f, capi.luakit.config_dir.."/"..f, "/etc/xdg/luakit/"..f }
    return find_file(paths)
end

--- Search and return the filepath of a file in the current working directory,
-- in the users $XDG_DATA_HOME/luakit/ or the luakit install dir.
-- @param f The relative filepath.
-- @return The first valid filepath or an error.
function find_data(f)
    if rstring.match(f, "^/") then return f end
    -- Search locations
    local paths = { f, capi.luakit.data_dir.."/"..f, capi.luakit.install_path.."/"..f }
    return find_file(paths)
end

--- Search and return the filepath of a file in the current working directory
-- or in the users $XDG_CACHE_HOME/luakit/
-- @param f The relative filepath.
-- @return The first valid filepath or an error.
function find_cache(f)
    -- Ignore absolute paths
    if rstring.match(f, "^/") then return f end
    -- Search locations
    local paths = { capi.luakit.cache_dir.."/"..f }
    return find_file(paths)
end

--- Parses scroll amounts.
-- @param current The current scroll amount.
-- @param max The maximum scroll amount.
-- @param value A value of the form: "+20%", "-20%", "+20px", "-20px", 20, "20%", "20px"
-- @return An absolute scroll amount.
function parse_scroll(current, max, value)
    if rstring.match(value, "^%d+px$") then
        return tonumber(rstring.match(value, "^(%d+)px$"))
    elseif rstring.match(value, "^%d+%%$") then
        return math.ceil(max * (tonumber(rstring.match(value, "^(%d+)%%$")) / 100))
    elseif rstring.match(value, "^[\-\+]%d+px") then
        return current + tonumber(rstring.match(value, "^([\-\+]%d+)px"))
    elseif rstring.match(value, "^[\-\+]%d+%%$") then
        return math.ceil(current + (max * (tonumber(rstring.match(value, "^([\-\+]%d+)%%$")) / 100)))
    else
        return error(rstring.format("unable to parse scroll amount: %q", value))
    end
end

--- Recursively traverse widget tree and return all widgets.
-- @param wi The widget.
function recursive_remove(wi)
    if not wi then return end
    local children = {}

    -- Remove pages from notebook widgets
    if wi.type == "notebook" then
        while wi:count() ~= 0 do
            local child = wi:atindex(-1)
            wi:remove(child)
            rtable.insert(children, child)
        end
    end

    -- Empty other container widgets
    if wi.get_children then
        for _, child in ipairs(wi:get_children()) do
            wi:remove(child)
            rtable.insert(children, child)
        end
    end

    -- Empty bin widgets
    if wi.get_child and wi:get_child() then
        local child = wi:get_child()
        wi:remove(child)
        rtable.insert(children, child)
    end

    for _, child in ipairs(children) do
        children = table.join(recursive_remove(child), children)
    end
    return children
end

--- Convert a number to string independent from locale.
-- @param num A number.
-- @param sigs Signifigant figures (if float).
-- @return The string representation of the number.
function ntos(num, sigs)
    local dec = rstring.sub(tostring(num % 1), 3, 2 + (sigs or 4))
    num = tostring(math.floor(num))
    return (#dec == 0 and num) or (num .. "." .. dec)
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
