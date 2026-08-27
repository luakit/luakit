--- Test runner path wrangler.
--
-- @script async.wrangle_paths
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

print("initial LUA_PATH: " .. package.path)
local system_paths_table, luakit_paths_table = {}, {}
for path in string.gmatch(package.path, "[^;]+") do
    if not path:match("^%./") and not path:find("luakit") then
        table.insert(system_paths_table, path)
    elseif not path:match("^%./") and path:find("luakit_test_") then
        table.insert(luakit_paths_table, path)
    end
end
local rel_paths_table = { "./lib/?.lua", "./lib/?/init.lua", "./config/?.lua", "./config/?/init.lua", }
local system_paths = table.concat(system_paths_table, ";")
local rel_paths = table.concat(rel_paths_table, ";")
local luakit_paths = table.concat(luakit_paths_table, ";")
package.path = string.format("./?.lua;%s;%s;%s", system_paths, rel_paths, luakit_paths)
print(package.path)

luakit.resource_path = "./resources" -- Don't use installed luakit when testing

-- vim: et:sw=4:ts=8:sts=4:tw=80
