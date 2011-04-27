--------------------------
-- WebKit WebView class --
--------------------------

-- Webview class table
webview = {}

-- Table of functions which are called on new webview widgets.
webview.init_funcs = {
    -- Set useragent
    set_useragent = function (view, w)
        view:set_property('user-agent', globals.useragent)
    end,

    -- Check if checking ssl certificates
    checking_ssl = function (view, w)
        local ca_file = soup.get_property("ssl-ca-file")
        if ca_file and os.exists(ca_file) then
            w.checking_ssl = true
        end
    end,

    -- Update window and tab titles
    title_update = function (view, w)
        view:add_signal("property::title", function (v)
            w:update_tablist()
            if w:is_current(v) then
                w:update_win_title()
            end
        end)
    end,

    -- Update uri label in statusbar
    uri_update = function (view, w)
        view:add_signal("property::uri", function (v)
            w:update_tablist()
            if w:is_current(v) then
                w:update_uri(v)
            end
        end)
    end,

    -- Update history indicator
    hist_update = function (view, w)
        view:add_signal("load-status", function (v, status)
            if w:is_current(v) then
                w:update_hist(v)
            end
        end)
    end,

    -- Update tab titles
    tablist_update = function (view, w)
        view:add_signal("load-status", function (v, status)
            if status == "provisional" or status == "finished" or status == "failed" then
                w:update_tablist()
            end
        end)
    end,

    -- Update scroll widget
    scroll_update = function (view, w)
        view:add_signal("expose", function (v)
            if w:is_current(v) then
                w:update_scroll(v)
            end
        end)
    end,

    -- Update progress widget
    progress_update = function (view, w)
        for _, sig in ipairs({"load-status", "property::progress"}) do
            view:add_signal(sig, function (v)
                if w:is_current(v) then
                    w:update_progress(v)
                    w:update_ssl(v)
                end
            end)
        end
    end,

    -- Display hovered link in statusbar
    link_hover_display = function (view, w)
        view:add_signal("link-hover", function (v, link)
            if w:is_current(v) and link then
                w:update_uri(v, nil, link)
            end
        end)
        view:add_signal("link-unhover", function (v)
            if w:is_current(v) then
                w:update_uri(v)
            end
        end)
    end,

    -- Clicking a form field automatically enters insert mode.
    form_insert_mode = function (view, w)
        view:add_signal("button-press", function (v, mods, button, context)
            -- Clear start search marker
            (w.search_state or {}).marker = nil

            if button == 1 and context.editable then
                view:emit_signal("form-active")
            end
        end)
        -- Emit root-active event in button release to prevent "missing"
        -- buttons or links when the input bar hides.
        view:add_signal("button-release", function (v, mods, button, context)
            if button == 1 and not context.editable then
                view:emit_signal("root-active")
            end
        end)
        view:add_signal("form-active", function ()
            if not w.mode.passthrough then
                w:set_mode("insert")
            end
        end)
        view:add_signal("root-active", function ()
            if w.mode.reset_on_focus ~= false then
                w:set_mode()
            end
        end)
    end,

    -- Catch keys in non-passthrough modes
    mode_key_filter = function (view, w)
        view:add_signal("key-press", function ()
            if not w.mode.passthrough then
                return true
            end
        end)
    end,

    -- Try to match a button event to a users button binding else let the
    -- press hit the webview.
    button_bind_match = function (view, w)
        view:add_signal("button-release", function (v, mods, button, context)
            (w.search_state or {}).marker = nil
            if w:hit(mods, button, { context = context }) then
                return true
            end
        end)
    end,

    -- Reset the mode on navigation
    mode_reset_on_nav = function (view, w)
        view:add_signal("load-status", function (v, status)
            if status == "provisional" and w:is_current(v) then
                if w.mode.reset_on_navigation ~= false then
                    w:set_mode()
                end
            end
        end)
    end,

    -- Domain properties
    domain_properties = function (view, w)
        view:add_signal("load-status", function (v, status)
            if status ~= "committed" or v.uri == "about:blank" then return end
            -- Get domain
            local domain = lousy.uri.parse(v.uri).host
            -- Strip leading www.
            domain = string.match(domain or "", "^www%.(.+)") or domain or "all"
            -- Build list of domain props tables to join & load.
            -- I.e. for luakit.org load .luakit.org, luakit.org, .org
            local props = {domain_props.all or {}, domain_props[domain] or {}}
            repeat
                table.insert(props, 2, domain_props["."..domain] or {})
                domain = string.match(domain, "%.(.+)")
            until not domain
            -- Join all property tables
            for k, v in pairs(lousy.util.table.join(unpack(props))) do
                info("Domain prop: %s = %s (%s)", k, tostring(v), domain)
                view:set_property(k, v)
            end
        end)
    end,

    -- Action to take on mime type decision request.
    mime_decision = function (view, w)
        -- Return true to accept or false to reject from this signal.
        view:add_signal("mime-type-decision", function (v, uri, mime)
            info("Requested link: %s (%s)", uri, mime)
            -- i.e. block binary files like *.exe
            --if mime == "application/octet-stream" then
            --    return false
            --end
        end)
    end,

    -- Action to take on window open request.
    window_decision = function (view, w)
        -- 'link' contains the download link
        -- 'reason' contains the reason of the request (i.e. "link-clicked")
        -- return TRUE to handle the request by yourself or FALSE to proceed
        -- with default behaviour
        view:add_signal("new-window-decision", function (v, uri, reason)
            info("New window decision: %s (%s)", uri, reason)
            if reason == "link-clicked" then
                window.new({uri})
            else
                w:new_tab(uri)
            end
            return true
        end)
    end,

    create_webview = function (view, w)
        -- Return a newly created webview in a new tab
        view:add_signal("create-web-view", function (v)
            return w:new_tab()
        end)
    end,

    -- Creates context menu popup from table (and nested tables).
    -- Use `true` for menu separators.
    populate_popup = function (view, w)
        view:add_signal("populate-popup", function (v)
            return {
                true,
                { "_Toggle Source", function () w:toggle_source() end },
                { "_Zoom", {
                    { "Zoom _In",    function () w:zoom_in()  end },
                    { "Zoom _Out",   function () w:zoom_out() end },
                    true,
                    { "Zoom _Reset", function () w:zoom_set() end }, }, },
            }
        end)
    end,

    -- Action to take on resource request.
    resource_request_decision = function (view, w)
        view:add_signal("resource-request-starting", function(v, uri)
            info("Requesting: %s", uri)
            -- Return false to cancel the request.
        end)
    end,
}

-- These methods are present when you index a window instance and no window
-- method is found in `window.methods`. The window then checks if there is an
-- active webview and calls the following methods with the given view instance
-- as the first argument. All methods must take `view` & `w` as the first two
-- arguments.
webview.methods = {
    stop   = function (view) view:stop() end,

    -- Reload with or without ignoring cache
    reload = function (view, w, bypass_cache)
        if bypass_cache then
            view:reload_bypass_cache()
        else
            view:reload()
        end
    end,

    -- Property functions
    get = function (view, w, k)
        return view:get_property(k)
    end,

    set = function (view, w, k, v)
        view:set_property(k, v)
    end,

    -- Evaluate javascript code and return string result
    -- The frame argument can be any of the following:
    -- * true to evaluate on the focused frame
    -- * false or nothing to evaluate on the main frame
    -- * a frame object to evaluate on the given frame
    eval_js = function (view, w, script, file, frame)
        return view:eval_js(script, file or "(inline)", frame)
    end,

    -- Evaluate javascript code from file and return string result
    -- The frame argument can be any of the following:
    -- * true to evaluate on the focused frame
    -- * false or nothing to evaluate on the main frame
    -- * a frame object to evaluate on the given frame
    eval_js_from_file = function (view, w, file, frame)
        local fh, err = io.open(file)
        if not fh then return error(err) end
        local script = fh:read("*a")
        fh:close()
        return view:eval_js(script, file, frame)
    end,

    -- Toggle source view
    toggle_source = function (view, w, show)
        local showing = view:get_view_source()
        if show == nil then show = not showing end
        if show ~= showing then view:set_view_source(show) end
    end,

    -- Zoom functions
    zoom_in = function (view, w, step, full_zoom)
        view:set_property("full-content-zoom", not not full_zoom)
        step = step or globals.zoom_step or 0.1
        view:set_property("zoom-level", view:get_property("zoom-level") + step)
    end,

    zoom_out = function (view, w, step, full_zoom)
        view:set_property("full-content-zoom", not not full_zoom)
        step = step or globals.zoom_step or 0.1
        view:set_property("zoom-level", math.max(0.01, view:get_property("zoom-level") - step))
    end,

    zoom_set = function (view, w, level, full_zoom)
        view:set_property("full-content-zoom", not not full_zoom)
        view:set_property("zoom-level", level or 1.0)
    end,

    -- Webview scroll functions
    scroll_vert = function (view, w, value)
        local cur, max = view:get_scroll_vert()
        if type(value) == "string" then
            value = lousy.util.parse_scroll(cur, max, value)
        end
        view:set_scroll_vert(value)
    end,

    scroll_horiz = function (view, w, value)
        local cur, max = view:get_scroll_horiz()
        if type(value) == "string" then
            value = lousy.util.parse_scroll(cur, max, value)
        end
        view:set_scroll_horiz(value)
    end,

    -- vertical scroll of a multiple of the view_size
    scroll_page = function (view, w, value)
        local cur, max, size = view:get_scroll_vert()
        view:set_scroll_vert(cur + (size * value))
    end,

    -- History traversing functions
    back = function (view, w, n)
        view:go_back(n or 1)
    end,

    forward = function (view, w, n)
        view:go_forward(n or 1)
    end,
}

function webview.new(w)
    local view = widget{type = "webview"}

    view.show_scrollbars = false

    -- Call webview init functions
    for k, func in pairs(webview.init_funcs) do
        func(view, w)
    end
    return view
end

-- Insert webview method lookup on window structure
table.insert(window.indexes, 1, function (w, k)
    -- Get current webview
    local view = w.tabs:atindex(w.tabs:current())
    if not view then return end
    -- Lookup webview method
    local func = webview.methods[k]
    if not func then return end
    -- Return webview method wrapper function
    return function (_, ...) return func(view, w, ...) end
end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
