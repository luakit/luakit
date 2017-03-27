--- Testing interface.
--
-- @module tests.lib
-- @copyright 2017 Aidan Holm

local filter_array = require("lib.lousy.util").table.filter_array

local _M = {}

local shared_lib = nil

function _M.init(arg)
    _M.init = nil
    shared_lib = arg
end

--- Pause test execution until a webview widget finishes loading.
--
-- @tparam widget view The webview widget to wait on.
function _M.wait_for_view(view)
    assert(type(view) == "widget" and view.type == "webview")
    shared_lib.traceback = debug.traceback("",2)
    repeat
        local _, status = _M.wait_for_signal(view, "load-status", 500)
        assert(status ~= "failed")
    until status == "finished"
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
-- @treturn string The URI prefix for the test HTTP server.
function _M.http_server()
    return "http://127.0.0.1:8888/"
end

local git_files

local function get_git_files ()
    if not git_files then
        git_files = {}
        local f = io.popen("git ls-files")
        for line in f:lines() do
            table.insert(git_files, line)
        end
        f:close()
    end

    return git_files
end

local function path_is_in_directory(path, dir)
    if path == "." then return true end
    return string.find(path, "^"..dir)
end

--- Retrieve a subset of files in the Luakit Git repository.
--
-- This function runs `git ls-files` and then filters the result according to
-- the provided parameters. It is mostly intended for use in code style tests.
-- The returned list of file paths includes all files that:
--
--  * are within at least one of the directories in `dirs`,
--  * match at least one of the Lua patterns in `patterns`, and
--  * do _not_ match any of the Lua patterns in `excludes`.
--
-- @tparam string|table dirs The directory prefix (or list of prefixes) in which
-- to look for files.
-- @tparam string|table patterns A Lua pattern (or list of patterns) with which
-- to filter file paths; non-matching files are removed.
-- @tparam[opt] table excludes A list of Lua patterns with which to filter file
-- paths; matching files are removed.
-- @treturn table A list of matching file paths.
function _M.find_files(dirs, patterns, excludes)
    assert(type(dirs) == "string" or type(dirs) == "table",
        "Bad search location: expected string or table")
    assert(type(patterns) == "string" or type(patterns) == "table",
        "Bad patterns: expected string or table")
    assert(excludes == nil or type(excludes) == "table",
        "Bad exclusion list: expected nil or table")

    if type(dirs) == "string" then dirs = { dirs } end
    if type(patterns) == "string" then patterns = { patterns } end
    if excludes == nil then excludes = {} end

    for _, dir in ipairs(dirs) do
        assert(type(dir) == "string", "Each search location must be a string")
    end
    for _, pattern in ipairs(patterns) do
        assert(type(pattern) == "string", "Each pattern must be a string")
    end
    for _, exclude in ipairs(excludes) do
        assert(type(exclude) == "string", "Each exclude must be a string")
    end

    -- Get list of files tracked by git
    get_git_files()

    -- Filter to those inside the given directories
    local file_list = {}
    for _, file in ipairs(git_files) do
        local dir_match = false
        for _, dir in ipairs(dirs) do
            dir_match = dir_match or path_is_in_directory(file, dir)
        end
        local pat_match = false
        for _, pattern in ipairs(patterns) do
            pat_match = pat_match or string.find(file, pattern)
        end
        if dir_match and pat_match then
            table.insert(file_list, file)
        end
    end

    -- Remove all files in excludes
    if excludes then
        file_list = filter_array(file_list, function (_, file)
            for _, exclude_pat in ipairs(excludes) do
                if string.find(file, exclude_pat) then return false end
            end
            return true
        end)
    end

    -- Return filtered list
    return file_list
end

--- A struct representing a file error.
-- @tfield string file The path of the file.
-- @tfield string err The error string.
-- @table entry

--- Helper function to format a list of file errors.
--
-- Aligns file names and file errors into two separate columns.
--
-- @tparam {entry} entries A list of file error entries.
-- @treturn string The formatted output string.
function _M.format_file_errors(entries)
    assert(type(entries) == "table")

    local sep = "    "

    -- Find file alignment length
    local align = 0
    get_git_files()
    for _, file in ipairs(git_files) do
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
