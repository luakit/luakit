local test = require "tests.lib"

local T = {}

local function read_file(file)
    local f = assert(io.open(file, "r"))
    local contents = f:read("*all")
    f:close()
    return contents
end

function T.test_module_blurb_not_empty ()
    local file_list = test.find_files({"lib", "doc/luadoc"}, "%.lua$",
        {"lib/lousy/widget/", "lib/lousy/init.lua", "lib/markdown.lua"})

    local errors = {}
    for _, file in ipairs(file_list) do
        local header = read_file(file):gsub("\n\n.*", "") .. "\n"
        -- Strip heading line, empty lines, @-lines, DOCMACRO lines
        local desc = header:gsub("^%-%-%-.-\n", ""):gsub("%-%- *\n", "")
        desc = desc:gsub("-- *%@.-\n", ""):gsub("^%-%- *DOCMACRO.-\n", "")
        if not desc:match("^%-%-") then
            table.insert(errors, { file = file, err = "Missing documentation" })
        end
    end

    if #errors > 0 then
        error("Some files do not have documentation:\n" .. test.format_file_errors(errors))
    end
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
