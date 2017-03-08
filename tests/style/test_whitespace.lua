local test = require "tests.lib"
local util = require "tests.util"
local join_table = require("lib.lousy.util").table.join

local T = {}

local function add_file_error(errors, file, error)
    table.insert(errors, { file = file, err = error })
end

function T.test_no_tabs_in_indentation ()
    local exclude_files = { "lib/markdown%.lua" }

    local errors = {}
    local file_list = {}
    file_list = join_table(file_list, util.find_files(".", "%.lua$", exclude_files))
    file_list = join_table(file_list, util.find_files(".", "%.[ch]$", exclude_files))

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
        test.fail("Some files have tabs in indentation:\n" .. util.format_file_errors(errors))
    end
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
