local test = require "tests.lib"

local T = {}

local function add_file_error(errors, file, error)
    table.insert(errors, { file = file, err = error })
end

function T.test_vim_modeline ()
    local errors = {}

    -- Test all C and H files
    local file_list = test.find_files("", "%.[ch]$")
    for _, file in ipairs(file_list) do
        -- Get file contents
        local f = assert(io.open(file, "r"))
        local contents = f:read("*all")
        f:close()

        local modeline_pat = "[^\n]\n\n// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80\n?$"
        if not contents:match(modeline_pat) then
            add_file_error(errors, file, "Missing/malformed modeline")
        end
    end

    -- Test all lua files
    file_list = test.find_files("", "%.lua$", {"lib/markdown.lua"})
    for _, file in ipairs(file_list) do
        -- Get file contents
        local f = assert(io.open(file, "r"))
        local contents = f:read("*all")
        f:close()

        local modeline_pat = "[^\n]\n\n%-%- vim: et:sw=4:ts=8:sts=4:tw=80\n?$"
        if not contents:match(modeline_pat) then
            add_file_error(errors, file, "Missing/malformed modeline")
        end
    end

    if #errors > 0 then
        error("Some files do not have modelines:\n" .. test.format_file_errors(errors))
    end
end

function T.test_include_guard ()
    local include_guard_pat = "#ifndef LUAKIT_%s\n#define LUAKIT_%s\n\n"
    local errors = {}

    local file_list = test.find_files("", "%.h$")
    for _, file in ipairs(file_list) do
        -- Get file contents
        local f = assert(io.open(file, "r"))
        local contents = f:read("*all")
        f:close()

        local s = file:gsub("[%.%/]", "_"):upper()
        local pat = include_guard_pat:format(s, s)
        if not contents:match(pat) then
            add_file_error(errors, file, "Missing/malformed include guard")
        end
    end

    if #errors > 0 then
        error("Some files do not have include guards:\n" .. test.format_file_errors(errors))
    end
end

local function get_first_paragraph_of_file(file)
    -- Get first paragraph of file
    local f = assert(io.open(file, "r"))
    local lines = {}
    for line in f:lines() do
        lines[#lines + 1] = line
        if line == "" then break end
    end
    local contents = table.concat(lines, "\n") .. "\n"
    f:close()
    return contents
end

function T.test_header_comment ()
    local file_desc_pat = "^%/%*\n %* (%S+) %- [^\n]*\n %*\n"
    local copyright_pat = " %* Copyright © [^\n]*\n"
    local gpl_text = [[
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

]]
    local errors = {}

    local file_list = test.find_files("", "%.[ch]$")
    for _, file in ipairs(file_list) do
        local contents = get_first_paragraph_of_file(file)

        local file_desc_name = contents:match(file_desc_pat)
        local bad_file_desc = file_desc_name and file_desc_name ~= file

        if bad_file_desc then
            local err = ("File description must match file name (expected %s, got %s)"):format(file, file_desc_name)
            add_file_error(errors, file, err)
        end
        if not contents:find(copyright_pat) then
            add_file_error(errors, file, "missing/malformed copyright line")
        end
        if not contents:find(gpl_text, 1, true) then
            add_file_error(errors, file, "missing/malformed GPL license text")
        end
    end

    if #errors > 0 then
        error("Some files have header comment errors:\n" .. test.format_file_errors(errors))
    end
end

function T.test_lua_header ()
    local exclude_files = { "lib/markdown%.lua" }

    local errors = {}

    local file_list = test.find_files("lib", "%.lua$", exclude_files)
    for _, file in ipairs(file_list) do
        local contents = get_first_paragraph_of_file(file)

        -- Check for module or submodule documentation tag
        local module_pat = "\n%-%- @module ([a-z_.]+)\n"
        local submodule_pat = "\n%-%- @submodule [a-z_.]+\n"
        local is_module = not not contents:find(module_pat)
        local is_submodule = not not contents:find(submodule_pat)
        if not is_module and not is_submodule then
            add_file_error(errors, file, "Must have a @module or @submodule line")
        elseif is_module and is_submodule then
            add_file_error(errors, file, "Cannot have both @module and @submodule lines")
        end

        -- Check for correct module name
        local module_name = contents:match(module_pat)
        if module_name then
            local expected_module_name = file:match("lib/(.*).lua"):gsub("/", "."):gsub(".init$","")
            if module_name ~= expected_module_name then
                local fmt = "Module name must match file name (expected %s, got %s)"
                local err = fmt:format(expected_module_name, module_name)
                add_file_error(errors, file, err)
            end
        end

        -- Check summary line
        local summary_pat = "^%-%-%-? [^\n]*%.\n"
        if not contents:find(summary_pat) then
            add_file_error(errors, file, "Missing/malformed summary line")
        end
        if is_module and not contents:match("^%-%-%- ") then
            add_file_error(errors, file, "Files with @module must start with ---")
        end
        if is_submodule and not contents:match("^%-%- ") then
            add_file_error(errors, file, "Files with @submodule must start with --")
        end
    end

    if #errors > 0 then
        error("Some Lua files have header comment errors:\n" .. test.format_file_errors(errors))
    end
end

function T.test_lua_module_uses_M ()
    local exclude_files = {
        "lib/markdown%.lua",           -- External file
        "lib/.*/init%.lua$",           -- Module groupings
        "lib/widget/%S*%.lua",         -- Status bar widgets
        "lib/introspector_chrome.lua", -- Deprecated module
    }

    local errors = {}

    local file_list = test.find_files("lib", "%.lua$", exclude_files)
    for _, file in ipairs(file_list) do
        -- Get file contents
        local f = assert(io.open(file, "r"))
        local contents = f:read("*all")
        f:close()

        -- Check for 'local _M = {}' in modules
        local module_pat = "\n%-%- @module ([a-z_.]+)\n"
        local is_module = not not contents:find(module_pat)
        if is_module then
            local _M_text = "\n\nlocal _M = {}\n\n"
            if not contents:find(_M_text, 1, true) then
                add_file_error(errors, file, "Missing/malformed module table declaration")
            end
        end
    end

    if #errors > 0 then
        error("Some Lua modules have module table declaration errors:\n" .. test.format_file_errors(errors))
    end
end

local function test_lua_module_function_documentation (errors, file, lines, A, B)
    local func = lines[B]:match("^function _M%.([^ %(]+)%(") or lines[B]:match("^_M%.(%S+) %= ")
    if lines[A] ~= "" then
        add_file_error(errors, file .. ":" .. tostring(A),
            "Blank line required before export")
        return
    end
    A = A + 1
    if A == B then
        add_file_error(errors, file .. ":" .. tostring(A), ("Undocumented export '%s'"):format(func))
        return
    end
    if not lines[A]:match("^%-%-%- ") then
        add_file_error(errors, file .. ":" .. tostring(A), "Documentation must start with '--- '")
    end
end

function T.test_lua_module_functions_are_documented ()
    local exclude_files = {
        "lib/markdown%.lua",   -- External file
    }

    local errors = {}

    local file_list = test.find_files("lib", "%.lua$", exclude_files)
    for _, file in ipairs(file_list) do
        -- Get file contents
        local f = assert(io.open(file, "r"))
        local lines = {}
        for line in f:lines() do
            lines[#lines + 1] = line
        end
        f:close()

        -- Find all lines with ^function _M.foo lines
        local func_lines = {}
        for i, line in ipairs(lines) do
            if line:match("^function _M%.") or line:match("^_M%.%S+ %= ")then
                func_lines[#func_lines+1] = i
            end
        end

        -- Find the bounds of the comment section
        for _, i in ipairs(func_lines) do
            local j = i
            repeat
                j = j - 1
            until j == 1 or not lines[j]:match("^%-%-")
            test_lua_module_function_documentation(errors, file, lines, j, i)
        end
    end

    if #errors > 0 then
        error("Some Lua modules have documentation issues:\n" .. test.format_file_errors(errors))
    end
end

function T.test_no_tabs_in_indentation ()
    local exclude_files = { "lib/markdown%.lua" }

    local errors = {}
    local file_list = test.find_files("", {"%.lua$", "%.[ch]$"}, exclude_files)

    for _, file in ipairs(file_list) do
        local lines = {}
        local f = assert(io.open(file, "r"))
        for line in f:lines() do
           lines[#lines+1] = line
        end
        f:close()

        for i, line in ipairs(lines) do
            if line:match("^(%s*)"):find("\t") then
                add_file_error(errors, file .. ":" .. i, "Tabs in indentation")
            end
        end
    end

    if #errors > 0 then
        error("Some files have tabs in indentation:\n" .. test.format_file_errors(errors))
    end
end

function T.test_no_trailing_whitespace ()
    local exclude_files = { "lib/markdown%.lua" }

    local errors = {}
    local file_list = test.find_files("", {"%.lua$", "%.[ch]$"}, exclude_files)

    for _, file in ipairs(file_list) do
        local lines = {}
        local f = assert(io.open(file, "r"))
        for line in f:lines() do
           lines[#lines+1] = line
        end
        f:close()

        for i, line in ipairs(lines) do
            if line:match("%s$") then
                add_file_error(errors, file .. ":" .. i, "Trailing whitespace")
            end
        end
    end

    if #errors > 0 then
        error("Some files have trailing whitespace:\n" .. test.format_file_errors(errors))
    end
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
