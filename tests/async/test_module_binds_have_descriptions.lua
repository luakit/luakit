--- Ensure all module bindings have descriptions.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local test = require("tests.lib")
local lousy = require("lousy")

local T = {}

local modes = require "modes"

local clear_all_mode_bindings = function ()
    local mode_list = modes.get_modes()
    for mode_name in pairs(mode_list) do
        local mode = modes.get_mode(mode_name)
        mode.binds = nil
    end
end

local get_mode_bindings_for_module = function (mod)
    -- First require() loads the module and all dependencies
    -- Second require() loads just the module
    require(mod)
    clear_all_mode_bindings()
    package.loaded[mod] = nil
    require(mod)

    local ret = {}

    local mode_list = modes.get_modes()
    for mode_name in pairs(mode_list) do
        local mode = modes.get_mode(mode_name)
        for _, m in pairs(mode.binds or {}) do
            local b, a = unpack(m)
            table.insert(ret, {
                name = lousy.bind.bind_to_string(b),
                desc = a.desc,
            })
        end
    end

    return ret
end

local function add_file_error(errors, file, error, ...)
    table.insert(errors, { file = file, err = string.format(error, ...) })
end

T.test_module_binds_have_descriptions = function ()
    local files = test.find_files({"lib/"}, ".+%.lua$", {"_wm%.lua$", "modes%.lua", "unique_instance%.lua"})

    local errors = {}

    for _, file in ipairs(files) do
        local pkg = file:gsub("^%a+/", ""):gsub("%.lua$", ""):gsub("/", ".")
        for _, b in ipairs(get_mode_bindings_for_module(pkg)) do
            if not b.desc or b.desc == "" then
                add_file_error(errors, file, "No description for binding %s", b.name)
            end
            if b.desc and not b.desc:match("%.$") then
                add_file_error(errors, file, "Description for binding %s doesn't end in a full stop.", b.name)
            end
            if b.desc and b.desc:match("^%l") then
                add_file_error(errors, file, "Description for binding %s isn't capitalized.", b.name)
            end
        end
    end

    if #errors > 0 then
        error("Some bindings are missing descriptions:\n" .. test.format_file_errors(errors))
    end
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
