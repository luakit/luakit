assert(luakit, "This file must be run as a luakit config file")

local find_files = require "build-utils.find_files"

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

local function bind_tostring(b)
    local t = b.type
    local m = b.mods

    if t == "key" then
        if m or string.wlen(b.key) > 1 then
            return "<".. (m and (m.."-") or "") .. b.key .. ">"
        else
            return b.key
        end
    elseif t == "buffer" then
        local p = b.pattern
        if string.sub(p,1,1) .. string.sub(p, -1, -1) == "^$" then
            return string.sub(p, 2, -2)
        end
        return b.pattern
    elseif t == "button" then
        return "<" .. (m and (m.."-") or "") .. "Mouse" .. b.button .. ">"
    elseif t == "any" then
        return "any"
    elseif t == "command" then
        local cmds = {}
        for i, cmd in ipairs(b.cmds) do
            cmds[i] = ":"..cmd
        end
        return cmds
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
                name = bind_tostring(b) or "???",
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
