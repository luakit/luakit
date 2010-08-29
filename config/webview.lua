--------------------------
-- WebKit WebView class --
--------------------------

-- Webview class table
webview = {}

-- Table of functions which are called on new webview widgets.
webview.init_funcs = {
    -- Set global properties
    set_global_props = function (view, w)
        -- Set proxy options
        local proxy = globals.http_proxy or os.getenv("http_proxy")
        if proxy then view:set_prop('proxy-uri', proxy) end
        view:set_prop('user-agent', globals.useragent)

        -- Set ssl options
        if globals.ssl_strict ~= nil then
            view:set_prop('ssl-strict', globals.ssl_strict)
        end
        if globals.ca_file and os.exists(globals.ca_file) then
            view:set_prop('ssl-ca-file', globals.ca_file)
            -- Warning: update the following variable if 'ssl-ca-file' is
            -- changed anywhere else.
            w.checking_ssl = true
        end
    end,

    -- Update window and tab titles
    title_update = function (view, w)
        view:add_signal("property::title", function (v)
            w:update_tab_labels()
            if w:is_current(v) then
                w:update_win_title()
            end
        end)
    end,

    -- Update uri label in statusbar
    uri_update = function (view, w)
        view:add_signal("property::uri", function (v)
            w:update_tab_labels()
            if w:is_current(v) then
                w:update_uri(v)
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
                w.sbar.l.uri.text = "Link: " .. lousy.util.escape(link)
            end
        end)
        view:add_signal("link-unhover", function (v)
            if w:is_current(v) then
                w:update_uri(v)
            end
        end)
    end,

    -- Clicking a form field automatically enters insert mode
    form_insert_mode = function (view, w)
        view:add_signal("form-active", function ()
            (w.search_state or {}).marker = nil
            w:set_mode("insert")
        end)
        view:add_signal("root-active", function ()
            (w.search_state or {}).marker = nil
            w:set_mode()
        end)
    end,

    -- Stop key events hitting the webview if the user isn't in insert mode
    mode_key_filter = function (view, w)
        view:add_signal("key-press", function ()
            if not w:is_mode("insert") then return true end
        end)
    end,

    -- Try to match a button event to a users button binding else let the
    -- press hit the webview.
    button_bind_match = function (view, w)
        -- Match button press
        view:add_signal("button-release", function (v, mods, button)
            (w.search_state or {}).marker = nil
            if w:hit(mods, button) then return true end
        end)
    end,

    -- Reset the mode on navigation
    mode_reset_on_nav = function (view, w)
        view:add_signal("load-status", function (v, status)
            if w:is_current(v) and status == "provisional" then w:set_mode() end
        end)
    end,

    -- Domain properties
    domain_properties = function (view, w)
        view:add_signal("load-status", function (v, status)
            if status ~= "provisional" then return end
            local domain = (v.uri and string.match(v.uri, "^%a+://([^/]*)/?")) or "about:blank"
            if string.match(domain, "^www.") then domain = string.sub(domain, 5) end
            local props = lousy.util.table.join(domain_props.all or {}, domain_props[domain] or {})
            for k, v in pairs(props) do
                info("Domain prop: %s = %s (%s)", k, tostring(v), domain)
                view:set_prop(k, v)
            end
        end)
    end,

    -- Action to take on mime type decision request.
    mime_decision = function (view, w)
        -- Return true to accept or false to reject from this signal.
        view:add_signal("mime-type-decision", function (v, link, mime)
            info("Requested link: %s (%s)", link, mime)
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
        view:add_signal("new-window-decision", function (v, link, reason)
            info("New window decision: %s (%s)", link, reason)
            if reason == "link-clicked" then
                window.new({ link })
                return true
            end
            w:new_tab(link)
        end)
    end,

    create_webview = function (view, w)
        -- Return a newly created webview in a new tab
        view:add_signal("create-web-view", function (v)
            return w:new_tab()
        end)
    end,

    -- Action to take on download request.
    download_request = function (view, w)
        -- 'link' contains the download link
        -- 'filename' contains the suggested filename (from server or webkit)
        view:add_signal("download-request", function (v, link, filename)
            if not filename then return end
            -- Make download dir
            os.execute(string.format("mkdir -p %q", globals.download_dir))
            local dl = globals.download_dir .. "/" .. filename
            local wget = string.format("wget -q %q -O %q", link, dl)
            info("Launching: %s", wget)
            luakit.spawn(wget)
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
                    { "Zoom _In",    function () w:zoom_in(globals.zoom_step) end },
                    { "Zoom _Out",   function () w:zoom_out(globals.zoom_step) end },
                    true,
                    { "Zoom _Reset", function () w:zoom_reset() end }, }, },
            }
        end)
    end,

    -- Action to take on resource request.
    resource_request_decision = function (view, w)
        view:add_signal("resource-request-starting", function(v, uri)
            if luakit.verbose then print("Requesting: "..uri) end
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
    reload = function (view, w)
        view:reload()
    end,

    -- Property functions
    get = function (view, w, k)
        return view:get_prop(k)
    end,

    set = function (view, w, k, v)
        view:set_prop(k, v)
    end,

    -- evaluate javascript code and return string result
    eval_js = function (view, w, script, file)
        return view:eval_js(script, file or "(inline)")
    end,

    -- evaluate javascript code from file and return string result
    eval_js_from_file = function (view, w, file)
        local fh, err = io.open(file)
        if not fh then return error(err) end
        local script = fh:read("*a")
        fh:close()
        return view:eval_js(script, file)
    end,

    -- close the current tab
    close_tab = function (view, w)
        w.tabs:remove(view)
        view.uri = "about:blank"
        view:destroy()
        w:update_tab_count()
        w:update_tab_labels()
    end,

    -- Toggle source view
    toggle_source = function (view, w, show)
        if show == nil then show = not view:get_view_source() end
        view:set_view_source(show)
    end,

    -- Zoom functions
    zoom_in = function (view, w, step)
        view:set_prop("zoom-level", view:get_prop("zoom-level") + step)
    end,

    zoom_out = function (view, w, step)
        local value = view:get_prop("zoom-level") - step
        view:set_prop("zoom-level", ((value > 0.01) and value) or 0.01)
    end,

    zoom_reset = function (view, w)
        view:set_prop("zoom-level", 1.0)
    end,

    -- Searching functions
    start_search = function (view, w, text)
        if string.match(text, "^[\?\/]") then
            w:set_mode("search")
            local i = w.ibar.input
            i.text = text
            i:focus()
            i:set_position(-1)
        else
            return error("invalid search term, must start with '?' or '/'")
        end
    end,

    search = function (view, w, text, forward)
        if forward == nil then forward = true end

        -- Get search state (or new state)
        if not w.search_state then w.search_state = {} end
        local s = w.search_state

        -- Get search term
        text = text or s.last_search
        if not text or #text == 0 then
            return w:clear_search()
        end
        s.last_search = text

        if s.forward == nil then
            -- Haven't searched before, save some state.
            s.forward = forward
            s.marker = view:get_scroll_vert()
        else
            -- Invert direction if originally searching in reverse
            forward = (s.forward == forward)
        end

        view:search(text, false, forward, true);
    end,

    clear_search = function (view, w)
        view:clear_search()
        w.search_state = {}
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

function webview.new(w, uri)
    local view = widget{type = "webview"}

    -- Call webview init functions
    for k, func in pairs(webview.init_funcs) do
        func(view, w)
    end

    if uri then view.uri = uri end
    view.show_scrollbars = false
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
