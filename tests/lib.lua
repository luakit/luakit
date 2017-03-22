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

function _M.wait_for_view(view)
    assert(type(view) == "widget" and view.type == "webview")
    repeat
        local _, status = _M.wait_for_signal(view, "load-status")
        assert(status ~= "failed")
    until status == "finished"
end

function _M.wait_for_signal(object, signal, timeout)
    assert(shared_lib.current_coroutine, "Not currently running in a test coroutine!")
    assert(coroutine.running() == shared_lib.current_coroutine, "Not currently running in the test coroutine!")
    assert(type(signal) == "string", "Expected string")
    assert(not timeout or type(timeout) == "number", "Expected number")

    return coroutine.yield({object, signal, timeout=timeout})
end

local waiting = false

function _M.wait(timeout)
    assert(shared_lib.current_coroutine, "Not currently running in a test coroutine!")
    assert(coroutine.running() == shared_lib.current_coroutine, "Not currently running in the test coroutine!")
    assert(not timeout or type(timeout) == "number", "Expected number")
    assert(not waiting, "Already waiting")

    waiting = true
    return coroutine.yield({timeout=timeout})
end

function _M.continue(...)
    assert(shared_lib.current_coroutine, "Not currently running in a test coroutine!")
    assert(waiting and (coroutine.running() ~= shared_lib.current_coroutine), "Not waiting, cannot continue")

    waiting = false
    shared_lib.resume_suspended_test(...)
end

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
