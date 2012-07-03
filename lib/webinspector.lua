--------------------------------------------------------
-- Bindings for the web inspector                     --
-- (C) 2012 Fabian Streitel <karottenreibe@gmail.com> --
-- (C) 2012 Mason Larobina <mason.larobina@gmail.com> --
--------------------------------------------------------

local windows = setmetatable({}, { __mode = "k" })

local function switch_inspector(w, view)
    -- Hide old widget
    if w.paned.bottom then w.paned:remove(w.paned.bottom) end
    -- Show new widget
    local iview = view.inspector
    if iview and not windows[iview] then
        w.paned:pack2(iview)
    end
end

local function close_window(iview)
    local win = windows[iview]
    if win then
        win:remove(iview)
        windows[iview] = nil
        win:destroy()
        return true
    end
end

window.init_funcs.inspector_setup = function (w)
    w.tabs:add_signal("switch-page", function (_, view)
        switch_inspector(w, view)
    end)
end

webview.init_funcs.inspector_setup = function (view, w)
    view.enable_developer_extras = true

    view:add_signal("create-inspector-web-view", function ()
        return widget{type="webview"}
    end)

    view:add_signal("show-inspector", function ()
        switch_inspector(w, view)
        -- We start in paned view
        view.inspector:eval_js("WebInspector.attached = true;")
    end)

    view:add_signal("close-inspector", function (_, iview)
        if not close_window(iview) then
            w.paned:remove(iview)
        end
        iview:destroy()
    end)

    view:add_signal("attach-inspector", function ()
        local iview = view.inspector
        close_window(iview)
        switch_inspector(w, view)
    end)

    view:add_signal("detach-inspector", function ()
        local iview = view.inspector
        local win = widget{type="window"}
        w.paned:remove(iview)
        win.child = iview
        windows[iview] = win
        win:show()
    end)
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
