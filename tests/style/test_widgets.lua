local test = require "tests.lib"

local T = {}

function T.test_widgets_use_macros()
    local errors = {}

    local file_list = test.find_files("widgets", "%.c$", {"widgets/webview/", "widgets/common.c"})
    for _, file in ipairs(file_list) do
        -- Get file contents
        local f = assert(io.open(file, "r"))
        local contents = f:read("*all")
        f:close()

        if not contents:find("LUAKIT_WIDGET_SIGNAL_COMMON") then
            table.insert(errors, { file = file, err = "Missing LUAKIT_WIDGET_SIGNAL_COMMON" })
        end
    end

    if #errors > 0 then
        error("Some widget wrappers have errors:\n" .. test.format_file_errors(errors))
    end
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
