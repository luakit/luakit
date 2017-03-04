require "lunit"
local luacheck = require "luacheck"
local lousy = require "lousy"

module("test_luacheck", lunit.testcase, package.seeall)

-- Modification of code by David Kastrup
-- From: http://lua-users.org/wiki/DirTreeIterator

local function files(dir, pattern)
    assert(dir and dir ~= "", "directory parameter is missing or empty")
    if string.sub(dir, -1) == "/" then
        dir = string.sub(dir, 1, -2)
    end

    local ignore = { ["."] = true, [".."] = true, [".git"] = true, ["tokenize.h"] = true, ["tokenize.c"] = true }

    local function yieldtree(dir)
        for entry in lfs.dir(dir) do
            if not ignore[entry] then
                entry = dir.."/"..entry
                local attr = lfs.attributes(entry)
                if attr.mode == "directory" then
                    yieldtree(entry)
                elseif attr.mode == "file" and entry:match(pattern) then
                    coroutine.yield(entry, attr)
                end
            end
        end
    end

    return coroutine.wrap(function() yieldtree(dir) end)
end

function test_luacheck ()
    local lua_dirs = {"lib", "config"}
    local exclude_files = {
        "lib/markdown.lua",
        "lib/cookie.*.lua",
        "lib/proxy.lua",
    }
    local options =  {
        std = "luajit",
    }
    local shared_globals = {
        "luakit",
        "soup",
        "msg",
        "ipc_channel",
    }
    local ui_globals = {
        "sqlite3",
        "lfs",
        "xdg",
        "timer",
        "download",
        "stylesheet",
        "unique",
        "widget",
        "uris",
        "require_web_module",
        "os",
    }
    local wm_globals = {
        "extension",
        "dom_document",
        "dom_element",
        "page",
    }
    local file_options = {
        ["lib/adblock.lua"] = {
            ignore = { "542" }, -- 542: Empty if branch
        },
    }

    wm_globals = lousy.util.table.join(shared_globals, wm_globals)
    ui_globals = lousy.util.table.join(shared_globals, ui_globals)

    -- Build list of all lua files in lua_dirs
    local file_list = {}
    for _, dir in ipairs(lua_dirs) do
        for file in files(dir, "%.lua$") do
            file_list[#file_list+1] = file
        end
    end

    -- Remove all files not tracked by git
    file_list = lousy.util.table.filter_array(file_list, function (_, file)
        local result = os.execute("git ls-files "..file.." --error-unmatch >/dev/null 2>&1")
        return result == 0
    end)

    -- Remove all files in exclude_files
    file_list = lousy.util.table.filter_array(file_list, function (_, file)
        for _, pattern in ipairs(exclude_files) do
            if string.find(file, pattern) then return false end
        end
        return true
    end)

    local warnings, errors, fatals = 0, 0, 0
    local issues = {}

    for _, file in ipairs(file_list) do
        -- Build options table for file
        local opts = lousy.util.table.clone(options)
        if string.match(file, ".*_wm%.lua$") then
            opts.globals = wm_globals
        else
            opts.globals = ui_globals
        end
        for pattern, subopts in pairs(file_options) do
            if string.match(file, pattern) then
                for k, v in pairs(subopts) do
                    opts[k] = v
                end
            end
        end

        -- Check file, collate any warning messages
        local report = luacheck.check_files({file}, opts)
        local file_report = report[1]
        for _, issue in ipairs(file_report) do
            local src = ("%s:%d: (%d:%d):"):format(file, issue.line, issue.column, issue.end_column)
            local msg = luacheck.get_message(issue)
            issues[#issues+1] = { src = src, msg = msg }
        end

        warnings = warnings + report.warnings
        errors = errors + report.errors
        fatals = fatals + report.fatals
    end

    if warnings + errors + fatals > 0 then
        local align = 0
        for _, issue in ipairs(issues) do
            align = math.max(align, issue.src:len())
        end

        local output = {}
        for _, issue in ipairs(issues) do
            output[#output + 1] = string.format("  %-" .. tostring(align+10) .. "s %s", issue.src, issue.msg)
        end
        fail("Luacheck messages:\n" .. table.concat(output, "\n"))
    end
end
