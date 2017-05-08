--------------------------
-- WebKit WebView class --
--------------------------

local window = require("window")
local lousy = require("lousy")
local globals = require("globals")

-- Webview class table
local webview = {}

lousy.signal.setup(webview, true)

local web_module = require_web_module("webview_wm")

web_module:add_signal("form-active", function (_, page_id)
    for _, w in pairs(window.bywidget) do
        if w.view.id == page_id then
            w.view:emit_signal("form-active")
        end
    end
end)

web_module:add_signal("navigate", function (_, page_id, uri)
    msg.verbose("Got luakit:// -> file:// navigation: %s", uri)
    for _, w in pairs(window.bywidget) do
        if w.view.id == page_id then w.view.uri = uri end
    end
end)

-- Deprecated API.
webview.init_funcs = { }

-- Table of functions which are called on new webview widgets.
local init_funcs = {
    -- Set useragent
    set_useragent = function (view)
        view.user_agent = globals.useragent
    end,

    -- Update window and tab titles
    title_update = function (view)
        view:add_signal("property::title", function (v)
            local w = webview.window(v)
            if w and w.view == v then
                w:update_win_title()
            end
        end)
    end,

    -- Clicking a form field automatically enters insert mode.
    form_insert_mode = function (view)
        -- Emit root-active event in button release to prevent "missing"
        -- buttons or links when the input bar hides.
        view:add_signal("button-release", function (v, _, button, context)
            if button == 1 and not context.editable then
                v:emit_signal("root-active")
            end
        end)
        view:add_signal("form-active", function (v)
            local w = webview.window(v)
            if not w.mode.passthrough then
                w:set_mode("insert")
            end
        end)
        view:add_signal("root-active", function (v)
            local w = webview.window(v)
            if w.mode.reset_on_focus ~= false then
                w:set_mode()
            end
        end)
        view:add_signal("load-status", function (v, status, _, err)
            if status == "finished" or (status == "failed" and err == "Load request cancelled") then
                web_module:emit_signal(v, "load-finished")
            end
        end)
    end,

    -- Catch keys in non-passthrough modes
    mode_key_filter = function (view)
        view:add_signal("key-press", function (v)
            local w = webview.window(v)
            if not w.mode.passthrough then
                return true
            end
        end)
    end,

    -- Try to match a button event to a users button binding else let the
    -- press hit the webview.
    button_bind_match = function (view)
        view:add_signal("button-release", function (v, mods, button, context)
            local w = webview.window(v)
            if w:hit(mods, button, { context = context }) then
                return true
            end
        end)
    end,

    -- Reset the mode on navigation
    mode_reset_on_nav = function (view)
        view:add_signal("load-status", function (v, status)
            local w = webview.window(v)
            if status == "provisional" and w and w.view == v then
                if w.mode.reset_on_navigation ~= false then
                    w:set_mode()
                end
            end
        end)
    end,

    -- Action to take on mime type decision request.
    mime_decision = function (view)
        -- Return true to accept or false to reject from this signal.
        view:add_signal("mime-type-decision", function (_, uri, mime)
            msg.info("Requested link: %s (%s)", uri, mime)
            -- i.e. block binary files like *.exe
            --if mime == "application/octet-stream" then
            --    return false
            --end
        end)
    end,

    -- Action to take on window open request.
    --window_decision = function (view, w)
    --    view:add_signal("new-window-decision", function (v, uri, reason)
    --        if reason == "link-clicked" then
    --            window.new({uri})
    --        else
    --            w:new_tab(uri)
    --        end
    --        return true
    --    end)
    --end,

    create_webview = function (view)
        -- Return a newly created webview in a new tab
        view:add_signal("create-web-view", function (v)
            return webview.window(v):new_tab()
        end)
    end,

    popup_fix_open_link_label = function (view)
        view:add_signal("populate-popup", function (_, menu)
            for _, item in ipairs(menu) do
                if type(item) == "table" then
                    -- Optional underscore represents alt-key shortcut letter
                    item[1] = string.gsub(item[1], "New (_?)Window", "New %1Tab")
                end
            end
        end)
    end,
}

-- These methods are present when you index a window instance and no window
-- method is found in `window.methods`. The window then checks if there is an
-- active webview and calls the following methods with the given view instance
-- as the first argument. All methods must take `view` & `w` as the first two
-- arguments.
webview.methods = {
    -- Reload with or without ignoring cache
    reload = function (view, _, bypass_cache)
        if bypass_cache then
            view:reload_bypass_cache()
        else
            view:reload()
        end
    end,

    -- Toggle source view
    toggle_source = function (view, _, show)
        if show == nil then
            view.view_source = not view.view_source
        else
            view.view_source = show
        end
        view:reload()
    end,

    -- Zoom functions
    zoom_in = function (view, _, step)
        step = step or globals.zoom_step or 0.1
        view.zoom_level = view.zoom_level + step
    end,

    zoom_out = function (view, _, step)
        step = step or globals.zoom_step or 0.1
        view.zoom_level = math.max(0.01, view.zoom_level) - step
    end,

    zoom_set = function (view, _, level)
        view.zoom_level = level or 1.0
    end,

    -- History traversing functions
    back = function (view, _, n)
        view:go_back(n or 1)
        view:emit_signal("go-back-forward", -(n or 1))
    end,

    forward = function (view, _, n)
        view:go_forward(n or 1)
        view:emit_signal("go-back-forward", (n or 1))
    end,
}

function webview.methods.scroll(view, w, new)
    local s = view.scroll
    for _, axis in ipairs{ "x", "y" } do
        -- Relative px movement
        if rawget(new, axis.."rel") then
            s[axis] = s[axis] + new[axis.."rel"]

        -- Relative page movement
        elseif rawget(new, axis .. "pagerel") then
            s[axis] = s[axis] + math.ceil(s[axis.."page_size"] * new[axis.."pagerel"])

        -- Absolute px movement
        elseif rawget(new, axis) then
            local n = new[axis]
            if n == -1 then
                local dir = axis == "x" and "Width" or "Height"
                local js = string.format([=[
                    Math.max(window.document.documentElement.scroll%s - window.inner%s, 0)
                ]=], dir, dir)
                w.view:eval_js(js, { callback = function (max)
                    s[axis] = max
                end})
            else
                s[axis] = n
            end

        -- Absolute page movement
        elseif rawget(new, axis.."page") then
            s[axis] = math.ceil(s[axis.."page_size"] * new[axis.."page"])

        -- Absolute percent movement
        elseif rawget(new, axis .. "pct") then
            local dir = axis == "x" and "Width" or "Height"
            local js = string.format([=[
                Math.max(window.document.documentElement.scroll%s - window.inner%s, 0)
            ]=], dir, dir)
            w.view:eval_js(js, { callback = function (max)
                s[axis] = math.ceil(max * (new[axis.."pct"]/100))
            end})
        end
    end
end

function webview.new()
    local view = widget{type = "webview"}

    -- Call webview init functions
    for _, func in pairs(init_funcs) do
        func(view)
    end
    if next(webview.init_funcs) then
        msg.warn("Modifying webview.init_funcs is deprecated and will be removed in a future version")
        msg.warn("Instead, connect to the 'init' signal on the webview module")
        for k, func in pairs(webview.init_funcs) do
            msg.warn("Webview init function '%s' using deprecated interface!", k)
            func(view)
        end
    end
    webview.emit_signal("init", view)

    return view
end

function webview.window(view)
    assert(type(view) == "widget" and view.type == "webview")
    local w = view
    repeat
        w = w.parent
    until w == nil or w.type == "window"
    return window.bywidget[w]
end

-- Insert webview method lookup on window structure
table.insert(window.indexes, 1, function (w, k)
    if k == "view" then
        local view = w.tabs[w.tabs:current()]
        if view and type(view) == "widget" and view.type == "webview" then
            w.view = view
            return view
        end
    end
    -- Lookup webview method
    local func = webview.methods[k]
    if not func then return end
    local view = w.view
    if view then
        return function (_, ...) return func(view, w, ...) end
    end
end)

return webview

-- vim: et:sw=4:ts=8:sts=4:tw=80
