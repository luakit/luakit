--- Main test runner.
--
-- @script run_test
-- @copyright 2017 Aidan Holm

-- Add ./tests to package.path
package.path = package.path .. ';./tests/?.lua'
package.path = package.path .. ';./lib/?.lua;./lib/?/init.lua'

local util = require "tests.util"
local posix = require "posix"

local prev_test_name
local function update_test_status(test_file, test_name, status)
    assert(type(test_file) == "string" and test_file:sub(1, 6) == "tests/")
    assert(type(test_name) == "string")
    assert(type(status) == "string")

    local esc = string.char(27)
    local c_red   = esc .. "[0;31m"
    local c_green = esc .. "[0;32m"
    local c_grey  = esc .. "[0;37m"
    local c_reset = esc .. "[0;0m"

    local status_color = ({
        pass = c_green,
        fail = c_red,
        wait = c_grey,
        cont = c_grey,
    })[status] or ""

    -- Overwrite the previous status line if it's for the same test
    if prev_test_name == test_name then
	io.write(esc .. "[1A" .. esc .. "[K")
    end
    prev_test_name = test_name

    print(status_color .. status:upper() .. c_reset .. " " .. test_name)
end

local function log_test_output(test_file, test_name, msg)
    assert(type(test_file) == "string" and test_file:sub(1, 6) == "tests/")
    assert(type(test_name) == "string")
    prev_test_name = nil
    local indent = "  "
    print("  " .. msg:gsub("\n", "\n" .. indent))
end

local function do_style_tests(test_files)
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
            update_test_status(test_file, test_name, ok and "pass" or "fail")
            if not ok and ret then
                log_test_output(test_file, test_name, ret)
            end
        end
    end
end

local function do_async_tests(test_files)
    -- Launch Xvfb
    local pid_xvfb = util.spawn({"Xvfb", ":1", "-screen", "0", "800x600x8"})

    for _, test_file in ipairs(test_files) do
        local command = "DISPLAY=:1 ./luakit -U --log=fatal -c tests/async/run_test.lua " .. test_file .. " 2>&1"
        local f = io.popen(command)
        for line in f:lines() do
            local status, test_name = line:match("^__(%a%a%a%a)__ ([%a_]+)$")
            if status and test_name then
                update_test_status(test_file, test_name, status)
            else
                log_test_output(test_file, test_name, line)
            end
        end
        f:close()
    end

    posix.kill(pid_xvfb)
end

local function do_lunit_tests(test_files)
    print("Running legacy tests...")
    local command = "./luakit --log=fatal -c tests/lunit-run.lua " .. table.concat(test_files, " ")
    os.execute(command)
end

local test_file_pat = "/test_[a-z_]*%.lua$"
local test_files = {
    style = util.find_files("tests/style/", test_file_pat),
    async = util.find_files("tests/async/", test_file_pat),
    lunit = util.find_files("tests/lunit/", test_file_pat),
}

do_style_tests(test_files.style)
do_async_tests(test_files.async)
do_lunit_tests(test_files.lunit)

util.cleanup()

-- vim: et:sw=4:ts=8:sts=4:tw=80
