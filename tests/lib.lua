--- Testing interface.
--
-- This module provides useful functions for use in luakit tests.
--
-- @module tests.lib
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local find_files = require "build-utils.find_files"

local _M = {}

local shared_lib = nil

-- Debug output configuration
_M.debug_enabled = os.getenv("LUAKIT_TEST_DEBUG") == "1"
_M.debug_indent = 0

function _M.init(arg)
    _M.init = nil
    shared_lib = arg
end

--- Output debug information during test execution.
--
-- When LUAKIT_TEST_DEBUG=1 environment variable is set, this function
-- outputs detailed debug information with timestamps and indentation.
--
-- @tparam string category The category of the debug message (e.g., "STATE", "ASSERT", "TIMING")
-- @param ... Values to output (will be converted to strings)
function _M.debug(category, ...)
    if not _M.debug_enabled then return end

    local timestamp = os.date("%H:%M:%S")
    local indent = string.rep("  ", _M.debug_indent)
    local args = {...}
    local parts = {}

    for i, v in ipairs(args) do
        if type(v) == "table" then
            parts[i] = _M.table_to_string(v)
        else
            parts[i] = tostring(v)
        end
    end

    local msg = table.concat(parts, " ")
    print(string.format("__debug__ [%s] [%s] %s%s", timestamp, category, indent, msg))
end

--- Increase debug output indentation level.
function _M.debug_push()
    _M.debug_indent = _M.debug_indent + 1
end

--- Decrease debug output indentation level.
function _M.debug_pop()
    _M.debug_indent = math.max(0, _M.debug_indent - 1)
end

--- Convert a table to a human-readable string.
--
-- @tparam table t The table to convert
-- @tparam[opt] number depth Current recursion depth (for internal use)
-- @treturn string String representation of the table
function _M.table_to_string(t, depth)
    depth = depth or 0
    if depth > 3 then return "{...}" end

    if type(t) ~= "table" then
        return tostring(t)
    end

    local parts = {}
    local indent = string.rep("  ", depth)

    for k, v in pairs(t) do
        local key = type(k) == "string" and k or "[" .. tostring(k) .. "]"
        local value
        if type(v) == "table" then
            value = _M.table_to_string(v, depth + 1)
        else
            value = tostring(v)
        end
        table.insert(parts, string.format("%s = %s", key, value))
    end

    if #parts == 0 then return "{}" end
    if #parts <= 3 then
        return "{ " .. table.concat(parts, ", ") .. " }"
    end

    return "{\n  " .. indent .. table.concat(parts, ",\n  " .. indent) .. "\n" .. indent .. "}"
end

--- Capture the state of a webview for debugging.
--
-- @tparam widget view The webview widget to inspect
-- @treturn table A table containing the webview state
function _M.capture_view_state(view)
    if type(view) ~= "widget" or view.type ~= "webview" then
        return {error = "Invalid view object"}
    end

    return {
        uri = view.uri or "nil",
        title = view.title or "nil",
        is_loading = view.is_loading or false,
        load_status = "unknown", -- Will be updated by signals
    }
end

--- Capture the state of a window for debugging.
--
-- @tparam table w The window object to inspect
-- @treturn table A table containing the window state
function _M.capture_window_state(w)
    if not w then
        return {error = "Window is nil"}
    end

    return {
        current_tab = w.tabs and w.tabs:current() or "nil",
        tab_count = w.tabs and w.tabs:count() or "nil",
        mode = w:is_mode() and tostring(w:is_mode()) or "unknown",
        view_uri = w.view and w.view.uri or "nil",
        view_title = w.view and w.view.title or "nil",
    }
end

--- Pause test execution until a webview widget finishes loading.
--
-- @tparam widget view The webview widget to wait on.
function _M.wait_for_view(view)
    assert(type(view) == "widget" and view.type == "webview")
    shared_lib.traceback = debug.traceback("",2)

    _M.debug("WAIT", "Waiting for view to finish loading:", view.uri or "unknown")
    _M.debug_push()

    local iteration = 0
    repeat
        iteration = iteration + 1
        _M.debug("SIGNAL", string.format("Iteration %d: waiting for load-status signal", iteration))

        local _, status, uri, err = _M.wait_for_signal(view, "load-status", 5000)

        _M.debug("SIGNAL", string.format("Received load-status: status=%s, uri=%s", status or "nil", uri or "nil"))

        if status == "failed" then
            _M.debug("ERROR", string.format("Load failed: %s", err or "unknown error"))
            local fmt = "tests.wait_for_view() failed loading '%s': %s"
            local msg = fmt:format(uri, err)
            assert(false, msg)
        end
    until status == "finished"

    _M.debug("WAIT", "View finished loading successfully")
    _M.debug_pop()
end

--- Pause test execution for a short time.
--
-- @tparam[opt] number timeout The time to delay, in milliseconds.
-- Defaults to 5 milliseconds.
function _M.delay(timeout)
    assert(not timeout or type(timeout) == "number", "Expected number")
    timeout = timeout or 5 -- "Sensible default" of 5ms
    local t = timer{interval = timeout}
    t:start()
    -- timeout+1000 ensures we don't fail the test while waiting
    _M.wait_for_signal(t, "timeout", timeout+1000)
end

--- Pause test execution until a predicate returns `true`.
--
-- Suspends test execution, polling the provided predicate function at an
-- interval, until the predicate returns a truthy value. If the predicate does
-- not return a truthy value within a certain time period, the running test fails.
--
-- @tparam function func The predicate function.
-- @tparam[opt] number poll_time The interval at which to poll the predicate, in
-- milliseconds. Defaults to 5 milliseconds.
-- @tparam[opt] number timeout Maximum time to wait before failing the running test,
-- in milliseconds. Defaults to 200 milliseconds.
function _M.wait_until(func, poll_time, timeout)
    assert(type(func) == "function", "Expected a function")
    assert(not poll_time or type(poll_time) == "number", "Expected number")
    assert(not timeout or type(timeout) == "number", "Expected number")

    shared_lib.traceback = debug.traceback("",2)

    poll_time = poll_time or 5
    timeout = timeout or 200

    local t = 0
    repeat
        _M.delay(poll_time)
        t = t + poll_time
        assert(t < timeout, "Timed out")
    until func()
end

--- Pause test execution until a particular signal is emitted on an object.
--
-- Suspends test execution until `signal` is emitted on `object`. If no such
-- signal is emitted on `object` within `timeout` milliseconds, the running test
-- fails.
--
-- @param object The object to wait for `signal` on.
-- @tparam string signal The signal to wait for.
-- @tparam[opt] number timeout Maximum time to wait before failing the running test,
-- in milliseconds. Defaults to 200 milliseconds.
function _M.wait_for_signal(object, signal, timeout)
    assert(shared_lib.current_coroutine, "Not currently running a test!")
    assert(coroutine.running() == shared_lib.current_coroutine, "Not currently running in the test coroutine!")
    assert(type(signal) == "string", "Expected string")
    assert(not timeout or type(timeout) == "number", "Expected number")

    shared_lib.traceback = debug.traceback("",2)

    timeout = timeout or 200
    return coroutine.yield({object, signal, timeout=timeout})
end

local waiting = false

--- Pause test execution indefinitely.
--
-- The running test is suspended until `continue()` is called. If `continue()`
-- is not called within `timeout` milliseconds, the running test fails.
--
-- @tparam[opt] number timeout Maximum time to wait before failing the running test,
-- in milliseconds. Defaults to 200 milliseconds.
-- @return All parameters to `continue()`.
function _M.wait(timeout)
    assert(shared_lib.current_coroutine, "Not currently running a test!")
    assert(coroutine.running() == shared_lib.current_coroutine, "Not currently running in the test coroutine!")
    assert(not timeout or type(timeout) == "number", "Expected number")
    assert(not waiting, "Already waiting")

    shared_lib.traceback = debug.traceback("",2)

    waiting = true
    timeout = timeout or 200
    return coroutine.yield({timeout=timeout})
end

--- Continue test execution.
--
-- The running test, currently suspended after a call to `wait()`, is resumed.
-- `wait()` must have been previously called.
--
-- All parameters to `continue()` are returned by `wait()`.
-- @param ... Values to return from `wait()`.
function _M.continue(...)
    assert(shared_lib.current_coroutine, "Not currently running a test!")
    assert(waiting and (coroutine.running() ~= shared_lib.current_coroutine), "Not waiting, cannot continue")

    waiting = false
    shared_lib.resume_suspended_test(...)
end

--- Get the URI prefix for the test HTTP server.
--
-- The port the test server listens on may not always be the same. This function
-- returns the current URI prefix, which looks like `http://127.0.0.1:8888/`.
--
-- Currently, however, there is no HTTP server; instead, the custom URI scheme
-- `luakit-test://` is used.
-- @treturn string The URI prefix for the test HTTP server.
function _M.http_server()
    return "luakit-test://"
end

--- Retrieve a subset of files in the current directory.
--
-- This function searches the directory and then filters the result
-- according to the provided parameters and the `.gitignore` file. It
-- is mostly intended for use in code style tests. The returned list of
-- file paths includes all files that:
--
--  * are within at least one of the directories in `dirs`,
--  * match at least one of the Lua patterns in `patterns`, and
--  * do _not_ match any of the Lua patterns in `excludes`.
--
-- @function find_files
-- @tparam string|table dirs The directory prefix (or list of prefixes) in which
-- to look for files.
-- @tparam string|table patterns A Lua pattern (or list of patterns) with which
-- to filter file paths; non-matching files are removed.
-- @tparam[opt] table excludes A list of Lua patterns with which to filter file
-- paths; matching files are removed.
-- @treturn table A list of matching file paths.

_M.find_files = find_files.find_files

--- Helper function to format a list of file errors.
--
-- Aligns file names and file errors into two separate columns.
--
-- @tparam {entry} entries A list of file error entries.
--
-- # `entry` format
--
--  - file: The path of the file.
--  - err: The error string.
-- @treturn string The formatted output string.
function _M.format_file_errors(entries)
    assert(type(entries) == "table")

    local sep = "    "

    -- Find file alignment length
    local align, luakit_files = 0, find_files.get_luakit_files()
    for _, file in ipairs(luakit_files) do
        align = math.max(align, file:len())
    end

    -- Build output
    local lines = {}
    local prev_file = nil
    for _, entry in ipairs(entries) do
        local file = entry.file ~= prev_file and entry.file or ""
        prev_file = entry.file
        local line = string.format("%-" .. tostring(align) .. "s%s%s", file, sep, entry.err)
        table.insert(lines, line)
    end
    return table.concat(lines, "\n")
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
