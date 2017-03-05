--- Utilities for use in tests.
--
-- @module tests.util
-- @copyright 2017 Aidan Holm

local lousy = require "lousy"

local M = {}

local function path_is_in_directory(path, dir)
    if path == "." then return true end
    return string.find(path, "^"..dir)
end

function M.find_files(dirs, pattern, excludes)
    assert(type(dirs) == "string" or type(dirs) == "table",
        "Bad search location: expected string or table")
    assert(type(pattern) == "string", "Bad pattern")
    assert(excludes == nil or type(excludes) == "table", "Bad exclusion list")

    if type(dirs) == "string" then dirs = { dirs } end
    for _, dir in ipairs(dirs) do
        assert(type(dir) == "string", "Each search location must be a string")
    end

    if excludes == nil then excludes = {} end

    -- Get list of files tracked by git
    local git_files = {}
    local f = io.popen("git ls-files")
    for line in f:lines() do
        table.insert(git_files, line)
    end
    local v = f:read("*all"):gsub("\n"," ")
    f:close()

    -- Filter to those inside the given directories
    local file_list = {}
    for _, file in ipairs(git_files) do
        local dir_match, pat_match = false, false
        for _, dir in ipairs(dirs) do
            dir_match = dir_match or path_is_in_directory(file, dir)
        end
        pat_match = string.find(file, pattern)
        if dir_match and pat_match then
            table.insert(file_list, file)
        end
    end

    -- Remove all files in excludes
    if excludes then
        file_list = lousy.util.table.filter_array(file_list, function (_, file)
            for _, pattern in ipairs(excludes) do
                if string.find(file, pattern) then return false end
            end
            return true
        end)
    end

    -- Return filtered list
    return file_list
end

return M
