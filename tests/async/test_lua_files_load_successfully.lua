--- Test that all files in config/ and lib/ can be included.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local test = require("tests.lib")

local T = {}

T.test_all_lua_files_load_successfully = function ()
    local exclude_files = { "config/rc.lua", "_wm%.lua$", "unique_instance%.lua" }
    local files = test.find_files({"config/", "lib/"}, ".+%.lua$", exclude_files)

    require "unique_instance"
    for _, file in ipairs(files) do
        local pkg = file:gsub("^%a+/", ""):gsub("%.lua$", ""):gsub("/", ".")
        require(pkg)
    end

    -- Wait for config file to finish loading
    luakit.idle_add(test.continue)
    test.wait()
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
