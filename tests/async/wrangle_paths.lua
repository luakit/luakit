--- Test runner path wrangler.
--
-- @script async.wrangle_paths
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local system_paths, luakit_paths = {}, {}
for path in string.gmatch(package.path, "[^;]+") do
    if not path:match("^%./") and not path:find("luakit") then
        table.insert(system_paths, path)
    elseif not path:match("^%./") and path:find("luakit_test_") then
        table.insert(luakit_paths, path)
    end
end
local rel_paths = { "./lib/?.lua", "./lib/?/init.lua", "./config/?.lua", "./config/?/init.lua", }
system_paths = table.concat(system_paths, ";")
rel_paths = table.concat(rel_paths, ";")
luakit_paths = table.concat(luakit_paths, ";")
package.path = string.format("./?.lua;%s;%s;%s", system_paths, rel_paths, luakit_paths)

luakit.resource_path = "./resources" -- Don't use installed luakit when testing

-- vim: et:sw=4:ts=8:sts=4:tw=80
