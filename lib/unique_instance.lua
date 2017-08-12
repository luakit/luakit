--- Unique instance support for luakit.
--
-- This module provides a simple implementation of unique instances.
-- With this module enabled, only one instance of luakit will be run;
-- opening links from other programs or from the command line will open
-- those links in an already-running instance of luakit.
--
-- This module should be the first module loaded in your configuration file.
--
-- @module unique_instance
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local _M = {}

-- Check that this module is loaded first: simple but effective
for _, k in ipairs({"window", "webview", "lousy", "globals"}) do
    assert(not package.loaded[k], "unique_instance should be loaded before all other modules!")
end

local lfs = require "lfs"
local unique = luakit.unique

if not unique then
    msg.verbose("luakit started with no-unique")
    return _M
end

unique.new("org.luakit")

-- Check for a running luakit instance
if unique.is_running() then
    msg.verbose("a primary instance is already running")
    if uris[1] then
        for _, uri in ipairs(uris) do
            if lfs.attributes(uri) then uri = os.abspath(uri) end
            unique.send_message("tabopen " .. uri)
        end
    else
        unique.send_message("winopen")
    end
    luakit.quit()
end

unique.add_signal("message", function (message, screen)
    msg.verbose("received message from secondary instance")
    local lousy = require "lousy"
    local window = require "window"
    local cmd, arg = string.match(message, "^(%S+)%s*(.*)")
    local ww = lousy.util.table.values(window.bywidget)[1]
    if cmd == "tabopen" then
        ww:new_tab(arg)
    elseif cmd == "winopen" then
        ww = window.new((arg ~= "") and { arg } or {})
    end
    ww.win.screen = screen
    ww.win.urgency_hint = true
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
