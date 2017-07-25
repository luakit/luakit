assert(luakit, "This file must be run as a luakit config file")

local find_files = require "build-utils.find_files"

-- Restrict Lua search path to just the build dir for luakit-related files
-- This is done by removing anything that looks like a luakit include dir
local paths = { "./config/?.lua", "./lib/?.lua", "./lib/?/init.lua" }
package.path:gsub("([^;]+)", function(path)
    if not path:find("/luakit/", 1, true) then
        table.insert(paths, path)
    end
end)
package.path = table.concat(paths, ";")

require "window"
require "webview"
require "binds"
local modes = require "modes"
local lousy = require "lousy"

local clear_all_mode_bindings = function ()
    local mode_list = modes.get_modes()
    for mode_name in pairs(mode_list) do
        local mode = modes.get_mode(mode_name)
        mode.binds = nil
    end
end

local get_mode_bindings_for_module = function (mod)
    require(mod)
    clear_all_mode_bindings()
    package.loaded[mod] = nil
    require(mod)

    local ret = {}

    local mode_list = modes.get_modes()
    for mode_name in pairs(mode_list) do
        local mode = modes.get_mode(mode_name)
        ret[mode_name] = {}
        for _, b in pairs(mode.binds or {}) do
            table.insert(ret[mode_name], {
                name = lousy.bind.bind_to_string(b) or "???",
                desc = b.desc,
            })
        end
    end

    return ret
end

local files = find_files.find_files({"lib/"}, ".+%.lua$", {"_wm%.lua$"})

local output = {}
for _, file in ipairs(files) do
    local pkg = file:gsub("^%a+/", ""):gsub("%.lua$", ""):gsub("/", ".")
    output[pkg] = get_mode_bindings_for_module(pkg)
end

io.stdout:write(lousy.pickle.pickle(output))

luakit.quit()

-- vim: et:sw=4:ts=8:sts=4:tw=80
