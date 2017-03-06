--- lousy.load library.
--
-- @module lousy.load
-- @author Mason Larobina &lt;mason.larobina@gmail.com&gt;
-- @copyright 2010 Mason Larobina
local capi = {
    luakit = luakit
}

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

local function search_load(path, memorize)
    assert(type(path) == "string", "invalid path")
    memorize = not not memorize

    if string.sub(path, 1, 1) ~= "/" then
        -- Can we search relative paths?
        if capi.luakit.dev_paths then
            local dat = load_resource("./"..path, memorize)
            if dat then return dat end
        end
        path = capi.luakit.install_path.."/"..path
    end

    return assert(load_resource(path, memorize),
        "unable to load resource: " .. path)
end

return setmetatable(_M, { __call = function (_, ...) return search_load(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
