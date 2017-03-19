local test = require "tests.lib"

local T = {}

function T.test_no_globalconf_in_common()
    local has_globalconf = {}
    local file_list = test.find_files("common", "%.[ch]$")
    for _, file in ipairs(file_list) do
        -- Get file contents
        local f = assert(io.open(file, "r"))
        local contents = f:read("*all")
        f:close()
        if contents:match("globalconf") then
            table.insert(has_globalconf, file)
        end
    end

    if #has_globalconf > 0 then
        local err = {}
        for _, file in ipairs(has_globalconf) do
            err[#err+1] = "  " .. file
        end
        error("Some files in common/ access globalconf:\n" .. table.concat(err, "\n"))
    end
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
