---------------------------------------------------------
-- Bindings for the web inspector                      --
-- (C) 2010 Fabian Streitel <karottenreibe@gmail.com>  --
---------------------------------------------------------

local windows = setmetatable({}, {__mode = "k"})

-- Register signal handlers and enable inspector.
webview.init_funcs.inspector = function (view, w)
    local switcher = function (_, v)
        local iview = view.inspector.widget
        local win = windows[iview]
        if view == v and v.inspector.visible then
            if win then win:show() end
            if iview then iview:show() end
        else
            if win then win:hide() end
            if iview then iview:hide() end
        end
    end
    view:set_property("enable-developer-extras", true)
    view:add_signal("show-inspector", function (_, iview)
        if not view.inspector.visible then
            iview:eval_js("WebInspector.toggleAttach();", "(webinspector.lua)")
            w.tabs:add_signal("switch-page", switcher)
        end
    end)
    view:add_signal("close-inspector", function (_, iview)
        w.tabs:remove_signal("switch-page", switcher)
        local win = windows[iview]
        if view.inspector.attached then
            w.layout:remove(iview)
        end
        if win then win:destroy() end
        windows[iview] = nil
    end)
    view:add_signal("attach-inspector", function (_, iview)
        local win = windows[iview]
        if win then win:remove(iview) end
        w.paned:pack2(iview)
        windows[iview] = nil
        if win then win:destroy() end
    end)
    view:add_signal("detach-inspector", function (_, iview)
        local win = widget{type="window"}
        w.layout:remove(iview)
        win:set_child(iview)
        windows[iview] = win
        win:show()
    end)
end

-- Toggle web inspector.
webview.methods.toggle_inspector = function (view, w, show)
    if show or not view.inspector.visible then
        view.inspector:show()
    else
        view.inspector:close()
    end
end

-- Add command to toggle inspector.
local cmd = lousy.bind.cmd
add_cmds({
    cmd({"inspect"},       function (w)    w:toggle_inspector(true) end),
    cmd({"inspect!"},      function (w)    w:toggle_inspector() end),
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
