--- Test runner for async tests.
--
-- @script async.run_test
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

-- Adjust paths to work when running with DEVELOPMENT_PATHS=0
dofile("tests/async/wrangle_paths.lua")
require_web_module("tests/async/wrangle_paths")

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
    local waiting_signal

    --- Runs a test untit it passes, fails, or waits for a signal
    -- Additional arguments: parameters to signal handler
    -- @treturn string Status of the test; one of "pass", "wait", "fail"
    local function begin_or_continue_test(func, ...)
        assert(type(func) == "thread")

        shared_lib.current_coroutine = func

        -- Run test until it finishes, pauses, or fails
        local ok, ret = coroutine.resume(func, ...)
        local state = coroutine.status(func)

        if not ok then
            print("__fail__ " .. current_test)
            print(tostring(ret))
            print(debug.traceback(func))
            return "fail"
        elseif state == "suspended" then
            print("__wait__ " .. current_test)

            -- Start timer
            wait_timer.interval = ret.timeout
            wait_timer:start()

            -- wait_for_signal
            if #ret == 2 then
                -- Add signal handlers to resume running test
                local obj, sig = ret[1], ret[2]
                local function wrapper(...)
                    obj:remove_signal(sig, wrapper)
                    shared_lib.resume_suspended_test(...)
                end
                obj:add_signal(sig, wrapper)
                waiting_signal = sig
            end

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
            print("__run__ " .. current_test)
            local test_status = begin_or_continue_test(func)
        until test_status == "wait"
    end

    --- Resumes a waiting test when a signal occurs
    shared_lib.resume_suspended_test = function (...)
        local func = shared_lib.current_coroutine
        assert(type(func) == "thread")
        -- Stop the timeout timer
        wait_timer:stop()
        waiting_signal = nil
        -- Continue the test
        print("__cont__ " .. current_test)
        local test_status = begin_or_continue_test(func, ...)
        -- If the test finished, do the next one
        if test_status ~= "wait" then
            luakit.idle_add(do_next_test)
        end
    end

    wait_timer:add_signal("timeout", function ()
        wait_timer:stop()
        print("__fail__ " .. current_test)
        if waiting_signal then
            print("Timed out while waiting for signal '" .. waiting_signal .. "'")
        else
            print("Timed out while waiting")
        end
        print("  interval was " .. tostring(wait_timer.interval) .. "msec")
        print("  " .. shared_lib.traceback)
        do_next_test()
    end)

    do_next_test()

    -- If the test hasn't opened any windows, open one to keep luakit happy
    if #luakit.windows == 0 then
        local win = widget{type="window"}
        win:show()
    end
end

io.stdout:setvbuf("line")

local test_file = uris[1]
assert(type(test_file) == "string")

-- Setup luakit-test:// URI scheme
luakit.register_scheme("luakit-test")
widget.add_signal("create", function (w)
    if w.type == "webview" then
        w:add_signal("scheme-request::luakit-test", function (_, uri, request)
            local path = uri:gsub("^luakit%-test://", "tests/html/")
            local f = assert(io.open(path, "rb"))
            local contents = f:read("*a") or ""
            f:close()

            local mime = "text/plain"
            if path:match("%.html$") then mime = "text/html" end
            if path:match("%.png$") then mime = "image/png" end
            if path:match("%.jpg$") then mime = "image/jpeg" end

            request:finish(contents, mime)
        end)
    end
end)

require('unique_instance')
local lousy = require('lousy')
-- Some lib files assume that a theme has been loaded
lousy.theme.init(lousy.util.find_config("theme.lua"))

do_test_file(test_file)

-- vim: et:sw=4:ts=8:sts=4:tw=80
