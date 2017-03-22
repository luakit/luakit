--- Test that all files in config/ and lib/ can be included.
--
-- @copyright Aidan Holm 2017

local tests = require("tests.lib")

local T = {}

T.test_all_lua_files_load_successfully = function ()
    local exclude_files = { "config/rc.lua", "_wm%.lua$" }
    local files = tests.find_files({"config/", "lib/"}, ".+%.lua$", exclude_files)

    for _, file in ipairs(files) do
        local pkg = file:gsub("^%a+/", ""):gsub("%.lua$", ""):gsub("/", ".")
        require(pkg)
    end

    -- Wait 50ms to allow luakit to finish loading config file
    local t = timer{interval = 50}
    t:start()
    tests.wait_for_signal(t, "timeout")
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
