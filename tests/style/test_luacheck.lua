local test = require "tests.lib"
local luacheck = require "luacheck"
local lousy = { util = require("lousy.util") }

local T = {}

function T.test_luacheck ()
    local lua_dirs = {"lib", "config", "tests", "build-utils"}
    local exclude_files = {
        "lib/markdown.lua",
    }
    local options =  {
        std = "luajit",
    }
    local shared_globals = {
        "luakit",
        "soup",
        "msg",
        "ipc_channel",
        "string.wlen",
        "regex",
        "utf8",
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
        ["config/rc.lua"] = {
            ignore = { "211" } -- 211: Unused variable
        },
        ["lib/adblock.lua"] = {
            ignore = { "542" }, -- 542: Empty if branch
        },
        ["tests/run_test.lua"] = {
            ignore = { "311/.*_prx" }, -- 311: Value assigned to variable is unused
        },
    }

    wm_globals = lousy.util.table.join(shared_globals, wm_globals)
    ui_globals = lousy.util.table.join(shared_globals, ui_globals)

    local file_list = test.find_files(lua_dirs, "%.lua$", exclude_files)

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
        error("Luacheck messages:\n" .. table.concat(output, "\n"))
    end
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
