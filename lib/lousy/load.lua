--- lousy.load library.
--
-- This module provides a function to search for and load the contents of
-- files.
--
-- @module lousy.load
-- @author Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local _M = {}

-- Keep loaded resources in memory
local data = {}

local function load_resource(path, memorize)
    -- Have we already loaded this resource?
    if memorize and data[path] then
        return data[path]
    end
    -- Attempt to open & read resource
    local file = io.open(path)
    if file then
        -- Read resource
        local dat = file:read("*a")
        file:close()
        -- Memorize if asked
        if memorize then data[path] = dat end
        -- Return file contents
        return dat
    end
end

--- @function __call
-- Load the contents of a file, with optional caching.
-- @tparam string path The path of the file to load. If the path is a relative
-- path, it is relative to the luakit installation path.
-- @tparam boolean memorize Whether file loads should be cached. If not `true`,
-- the cache will not be queried for an already-loaded copy, nor will the cache
-- be populated on a successful load.

local function search_load(path, memorize)
    assert(type(path) == "string", "invalid path")
    memorize = not not memorize

    if string.sub(path, 1, 1) ~= "/" then
        -- Can we search relative paths?
        if luakit.dev_paths then
            local dat = load_resource("./"..path, memorize)
            if dat then return dat end
        end
        path = luakit.install_paths.install_dir.."/"..path
    end

    return assert(load_resource(path, memorize),
        "unable to load resource: " .. path)
end

return setmetatable(_M, { __call = function (_, ...) return search_load(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
