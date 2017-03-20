--- Test that all files in config/ and lib/ can be included.
--
-- @copyright Aidan Holm 2017

local join_table = require("lib.lousy.util").table.join
local tests = require("tests.lib")

local T = {}

T.test_all_lua_files_load_successfully = function ()
    local pattern = ".+%.lua$"
    local exclude_files = {
        "config/rc.lua",
        "_wm%.lua$",
        "lib/lousy/",
    }

    local config_files = tests.find_files("config", "^config/" .. pattern, exclude_files)
    local lib_files = tests.find_files("lib", "^lib/" .. pattern, exclude_files)
    local files = join_table(config_files, lib_files)

    for _, file in ipairs(files) do
        local pkg = file:gsub("^%a+/", ""):gsub("%.lua$", ""):gsub("/", ".")
        require(pkg)
    end

    -- Wait 50ms to allow luakit to finish loading config file
    local t = timer{interval = 50}
    t:start()
    tests.wait_for_signal(t, "timeout", 1)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
