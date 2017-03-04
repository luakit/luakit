require "lunit"
require "lfs"

module("test_source_format", lunit.testcase, package.seeall)

-- Modification of code by David Kastrup
-- From: http://lua-users.org/wiki/DirTreeIterator

function files(dir, pattern)
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

function test_vim_modeline ()
    local modeline_pat = "[^\n]\n\n// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80\n?$"
    local missing = {}

    for file in files(".", "%.[ch]$") do
        -- Get file contents
        local f = assert(io.open(file, "r"))
        local contents = f:read("*all")
        f:close()
        if not contents:match(modeline_pat) then
            table.insert(missing, file)
        end
    end

    if #missing > 0 then
        local err = {}
        for _, file in ipairs(missing) do
            err[#err+1] = "  " .. file:sub(3)
        end
        fail("Some files do not have modelines:\n" .. table.concat(err, "\n"))
    end
end

function test_include_guard ()
    local include_guard_pat = "#ifndef LUAKIT_%s\n#define LUAKIT_%s\n\n"
    local missing = {}

    for file in files(".", "%.h$") do
        -- Get file contents
        local f = assert(io.open(file, "r"))
        local contents = f:read("*all")
        f:close()

        local s = file:sub(3):gsub("[%.%/]", "_"):upper()
        local pat = include_guard_pat:format(s, s)
        if not contents:match(pat) then
            table.insert(missing, file)
        end
    end

    if #missing > 0 then
        local align = 0
        for _, file in ipairs(missing) do
            align = math.max(align, file:len())
        end

        local err = {}
        for _, file in ipairs(missing) do
            local s = file:sub(3):gsub("[%.%/]", "_"):upper()
            err[#err+1] = string.format("  %-" .. tostring(align-1) .. "sexpected LUAKIT_%s", file:sub(3), s)
        end
        fail("Some files do not have include guards:\n" .. table.concat(err, "\n"))
    end
end

function test_header_comment ()
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
    local missing = {}

    for file in files(".", "%.[ch]$") do
        -- Get first paragraph of file
        local f = assert(io.open(file, "r"))
        local lines = {}
        for line in f:lines() do
            lines[#lines + 1] = line
            if line == "" then break end
        end
        local contents = table.concat(lines, "\n") .. "\n"
        f:close()

        local file_desc_name = contents:match(file_desc_pat)
        local bad_file_desc = file_desc_name and file_desc_name ~= file:sub(3)
        local no_copyright = not contents:find(copyright_pat)
        local no_gpl_text = not contents:find(gpl_text, 1, true)

        if bad_file_desc or no_copyright or no_gpl then
            local errors = {}
            if bad_file_desc then errors[#errors+1] = "file description" end
            if no_copyright then errors[#errors+1] = "copyright line" end
            if no_gpl_text then errors[#errors+1] = "GPL license text" end
            table.insert(missing, {
                file = file,
                err = table.concat(errors, ", ")
            })
        end
    end

    if #missing > 0 then
        local align = 0
        for _, entry in ipairs(missing) do
            align = math.max(align, entry.file:len())
        end

        local err = {}
        for _, entry in ipairs(missing) do
            err[#err+1] = string.format("  %-" .. tostring(align-1) .. "s bad/missing %s", entry.file:sub(3), entry.err)
        end
        fail("Some files have header comment errors:\n" .. table.concat(err, "\n"))
    end
end
