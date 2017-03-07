--- Main test runner.
--
-- @script run_test
-- @copyright 2017 Aidan Holm

-- Add ./tests to package.path
package.path = package.path .. ';./tests/?.lua'

local util = require "tests.util"
local posix = require "posix"

--- Global testing library
test = {
    fail = function (msg)
        error(msg, 0)
    end,
}

local function do_style_tests()
    -- Load and run all style tests
    local test_files = util.find_files("tests/style/", "/test_[a-z_]*%.lua$")
    for _, test_file in ipairs(test_files) do
        -- Load test table
        local chunk, err = loadfile(test_file)
        assert(chunk, err)
        local T = chunk()
        assert(type(T) == "table")

        for test_name, func in pairs(T) do
            assert(type(test_name) == "string")
            assert(type(func) == "function")

            local ok, ret = pcall(func)
            print((ok and "PASS" or "FAIL") .. ": " .. test_name)
            if not ok then
                print(ret)
            end
        end
    end
end

local function do_async_tests()
    -- Launch Xvfb
    local pid_xvfb = util.spawn({"Xvfb", ":1", "-screen", "0", "800x600x8"})

    -- Load and run all async tests
    local test_files = util.find_files("tests/async/", "/test_[a-z_]*%.lua$")
    for _, test_file in ipairs(test_files) do
        local command = "DISPLAY=:1 ./luakit -U --log=fatal -c tests/async/run_test.lua " .. test_file .. " 2>&1"
        os.execute(command)
    end

    posix.kill(pid_xvfb)
end

do_style_tests()
do_async_tests()
util.cleanup()

-- vim: et:sw=4:ts=8:sts=4:tw=80
