--- Bindings for the web inspector.
--
-- @module webinspector
-- @copyright 2012 Fabian Streitel <karottenreibe@gmail.com>
-- @copyright 2012 Mason Larobina <mason.larobina@gmail.com>

local webview = require("webview")
local lousy = require("lousy")
local binds = require("binds")
local add_cmds = binds.add_cmds

local _M = {}

webview.init_funcs.inspector_setup = function (view)
    view.enable_developer_extras = true
end

local cmd = lousy.bind.cmd
add_cmds({
    cmd("in[spect]", "open DOM inspector", function (w, _, o)
        local v = w.view
        if o.bang then -- "inspect!" toggles inspector
            (v.inspector and v.close_inspector or v.show_inspector)(v)
        else
            w.view:show_inspector()
        end
    end),
})

return _M
