local test = require "tests.lib"

local T = {}

local function add_file_error(errors, file, error)
    table.insert(errors, { file = file, err = error })
end

function T.test_no_tabs_in_indentation ()
    local exclude_files = { "lib/markdown%.lua" }

    local errors = {}
    local file_list = test.find_files(".", {"%.lua$", "%.[ch]$"}, exclude_files)

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
    local file_list = test.find_files(".", {"%.lua$", "%.[ch]$"}, exclude_files)

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
