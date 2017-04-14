local filter_array = require("lib.lousy.util").table.filter_array
local lua_escape = require("lib.lousy.util").lua_escape

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
    return string.find(path, "^"..lua_escape(dir))
end

local function find_files(dirs, patterns, excludes)
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

return {
    get_git_files = get_git_files,
    find_files = find_files,
}

-- vim: et:sw=4:ts=8:sts=4:tw=80
