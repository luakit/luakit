--- Test runner for async tests.
--
-- @script async.run_test
-- @copyright 2017 Aidan Holm

local shared_lib = {}
local priv = require "tests.priv"
local test = require("tests.lib")
test.init(shared_lib)

--- Launched as the init script of a luakit instance
--
-- Loads test_file and runs all tests in it in order
local function do_test_file(test_file)
    local wait_timer = timer()

    -- Load test table, or abort
    print("__load__ ")
    local T, err = priv.load_test_file(test_file)
    if not T then
        print("__fail__ " .. test_file)
        print(err)
        luakit.quit(0)
    end

    -- Convert functions to coroutines
    for test_name, func in pairs(T) do
        if type(func) == "function" then
            T[test_name] = coroutine.create(func)
        end
    end

    local current_test
    local waiting_signal = "???"

    local test_object_signal_handler

    --- Runs a test untit it passes, fails, or waits for a signal
    -- Additional arguments: parameters to signal handler
    -- @treturn string Status of the test; one of "pass", "wait", "fail"
    local function begin_or_continue_test(test_name, func, ...)
        assert(type(test_name) == "string")
        assert(type(func) == "thread")

        if shared_lib.current_coroutine ~= func then
            print("__run__ " .. current_test)
        end
        shared_lib.current_coroutine = func

        -- Run test until it finishes, pauses, or fails
        local ok, ret = coroutine.resume(func, ...)
        local state = coroutine.status(func)

        if not ok then
            print("__fail__ " .. current_test)
            print(tostring(ret))
            return "fail"
        elseif state == "suspended" then
            print("__wait__ " .. current_test)

            -- Start timer
            local interval = ret.timeout * 1000
            wait_timer.interval = interval
            wait_timer:start()

            -- Add signal handlers to resume running test
            local obj, sig = ret[1], ret[2]
            local function wrapper(...)
                obj:remove_signal(sig, wrapper)
                test_object_signal_handler(test_name, func, ...)
            end
            obj:add_signal(sig, wrapper)
            waiting_signal = sig

            -- Return to luakit
            return "wait"
        else
            print("__pass__ " .. current_test)
            return "pass"
        end
    end

    --- Finds the next test to run and starts it, or quits
    local function do_next_test()
        repeat
            local test_name, func = next(T, current_test)
            if not test_name then
                -- Quit if all tests have been run
                luakit.quit()
                return
            end
            current_test = test_name

            local test_status = begin_or_continue_test(test_name, func)
        until test_status == "wait"
    end

    --- Resumes a waiting test when a signal occurs
    test_object_signal_handler = function (test_name, func, ...)
        assert(type(test_name) == "string")
        assert(type(func) == "thread")
        -- Stop the timeout timer
        wait_timer:stop()
        -- Continue the test
        print("__cont__ " .. current_test)
        local test_status = begin_or_continue_test(test_name, func, ...)
        -- If the test finished, do the next one
        if test_status ~= "wait" then
            luakit.idle_add(function()
                do_next_test()
                return false
            end)
        end
    end

    wait_timer:add_signal("timeout", function ()
        wait_timer:stop()
        print("__fail__ " .. current_test)
        print("  Timed out waiting for signal '" .. waiting_signal .. "'")
        do_next_test()
    end)

    do_next_test()
end

io.stdout:setvbuf("line")

local test_file = uris[1]
assert(type(test_file) == "string")

do_test_file(test_file)

-- vim: et:sw=4:ts=8:sts=4:tw=80
