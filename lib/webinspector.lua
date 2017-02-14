--------------------------------------------------------
-- Bindings for the web inspector                     --
-- (C) 2012 Fabian Streitel <karottenreibe@gmail.com> --
-- (C) 2012 Mason Larobina <mason.larobina@gmail.com> --
--------------------------------------------------------
local webview = require("webview")

webview.init_funcs.inspector_setup = function (view, w)
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
