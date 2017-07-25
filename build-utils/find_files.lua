local filter_array = require("lib.lousy.util").table.filter_array
local lua_escape = require("lib.lousy.util").lua_escape

local luakit_files

local function get_luakit_files ()
    if not luakit_files then
        luakit_files = {}
        local f = io.popen("find . -type f | grep -v '\\./\\.' | sed 's#^\\./##'")
        for line in f:lines() do
            -- Check file against filters derived from .gitignore
            local ok = true
            ok = ok and not line:match("^doc/apidocs/")
            ok = ok and not line:match("^doc/html/")
            ok = ok and not line:match("%.o$")
            ok = ok and not line:match("%.1$")
            ok = ok and not line:match("%.swp$")
            ok = ok and not line:match("~$")
            ok = ok and not line:match("^common/tokenize.[ch]$")
            ok = ok and not ({
                ["luakit"] = true, ["luakit.so"] = true, ["luakit.1.gz"] = true,
                ["tests/util.so"] = true, ["buildopts.h"] = true, ["tags"] = true,
            })[line]
            if ok then table.insert(luakit_files, line) end
        end
        f:close()
    end

    return luakit_files
end

local function path_is_in_directory(path, dir)
    if path == "." then return true end
    return string.find(path, "^"..lua_escape(dir))
end

local function find_files(dirs, patterns, excludes)
    assert(dirs ~= ".", "Bad pattern '.'; use empty string instead")
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

    -- Get list of files tracked by luakit
    get_luakit_files()

    -- Filter to those inside the given directories
    local file_list = {}
    for _, file in ipairs(luakit_files) do
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
    get_luakit_files = get_luakit_files,
    find_files = find_files,
}

-- vim: et:sw=4:ts=8:sts=4:tw=80
