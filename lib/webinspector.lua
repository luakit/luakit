--- Bindings for the web inspector.
--
-- This module enables developer extras for luakit's web views, and adds a
-- command to show/hide the WebKit web inspector.
--
-- @module webinspector
-- @copyright 2012 Fabian Streitel <karottenreibe@gmail.com>
-- @copyright 2012 Mason Larobina <mason.larobina@gmail.com>

local webview = require("webview")
local settings = require("settings")
local modes     = require("modes")
local add_cmds  = modes.add_cmds

local _M = {}

webview.add_signal("init", function (view)
    settings.override_setting_for_view(view, "webview.enable_developer_extras", true)
end)

add_cmds({
    { ":in[spect]", "Open the DOM inspector.", function (w, o)
        local v = w.view
        if o.bang then -- "inspect!" toggles inspector
            (v.inspector and v.close_inspector or v.show_inspector)(v)
        else
            w.view:show_inspector()
        end
    end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
