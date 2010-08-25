--------------------------
-- WebKit WebView class --
--------------------------

-- Webview class table
webview = {}

local function set_http_options(view)
    local proxy = globals.http_proxy or os.getenv("http_proxy")
    if proxy then view:set_prop('proxy-uri', proxy) end
    local rv, out, err = luakit.spawn_sync("uname -sm")
    view:set_prop('user-agent', globals.useragent)
    -- Uncomment the following options if you want to enable SSL certs validation.
    -- w:set('ssl-ca-file', '/etc/certs/ca-certificates.crt')
    -- w:set('ssl-strict', true)
end

-- Attach signal handlers to a new tab's webview
local function attach_webview_signals(view, w)
    view:add_signal("property::title", function (v)
        w:update_tab_labels()
        if w:is_current(v) then
            w:update_win_title(v)
        end
    end)

    view:add_signal("property::uri", function (v)
        w:update_tab_labels()
        if w:is_current(v) then
            w:update_uri(v)
        end
    end)

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

    view:add_signal("form-active", function ()
        w:set_mode("insert")
    end)

    view:add_signal("root-active", function ()
        w:set_mode()
    end)

    view:add_signal("key-press", function ()
        -- Only allow key press events to hit the webview if the user is in
        -- "insert" mode.
        if not w:is_mode("insert") then
            return true
        end
    end)

    view:add_signal("button-release", function (v, mods, button)
        -- Prevent a click from causing the search to think you pressed
        -- escape and return you to the start search marker.
        w.search_start_marker = nil

        if w:hit(mods, button) then
            return true
        end
    end)

    -- Update progress widgets & set default mode on navigate
    view:add_signal("load-status", function (v, status)
        if w:is_current(v) then
            w:update_progress(v)
            if status == "provisional" then
                w:set_mode()
            end
        end
    end)

    -- Domain properties
    view:add_signal("load-status", function (v, status)
        if status == "committed" then
            local domain = string.match(v.uri, "^%a+://([^/]*)/?") or "other"
            if string.match(domain, "^www.") then domain = string.sub(domain, 5) end
            local props = lousy.util.table.join(domain_props.all or {}, domain_props[domain] or {})
            for k, v in pairs(props) do
                info("Domain prop: %s = %s (%s)", k, tostring(v), domain)
                view:set_prop(k, v)
            end
        end
    end)

    -- 'link' contains the download link
    -- 'mime' contains the mime type that is requested
    -- return TRUE to accept or FALSE to reject
    view:add_signal("mime-type-decision", function (v, link, mime)
        info("Requested link: %s (%s)", link, mime)
        -- i.e. block binary files like *.exe
        --if mime == "application/octet-stream" then
        --    return false
        --end
    end)

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

    view:add_signal("create-web-view", function (v)
        return w:new_tab()
    end)

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

    view:add_signal("property::progress", function (v)
        if w:is_current(v) then
            w:update_progress(v)
        end
    end)

    view:add_signal("expose", function (v)
        if w:is_current(v) then
            w:update_scroll(v)
        end
    end)

    view:add_signal("resource-request-starting", function(v, uri)
        if luakit.verbose then print("Requesting: "..uri) end
        -- Return false to cancel the request.
    end)
end

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
    start_search = function (view, w, forward)
        -- Clear previous search results
        w:clear_search()
        w:set_mode("search")
        local i = w.ibar.input
        if forward then
            i.text = "/"
        else
            i.text = "?"
        end
        i:focus()
        i:set_position(-1)
    end,

    search = function (view, w, text, forward)
        local text = text or w.last_search
        if forward == nil then forward = true end
        local case_sensitive = false
        local wrap = true

        if not text or #text == 0 then
            w:clear_search()
            return nil
        end

        w.last_search = text
        if w.searching_forward == nil then
            w.searching_forward = forward
            w.search_start_marker = view:get_scroll_vert()
        else
            -- Invert the direction if originally searching in reverse
            forward = (w.searching_forward == forward)
        end

        view:search(text, case_sensitive, forward, wrap);
    end,

    clear_search = function (view, w)
        view:clear_search()
        -- Clear search state
        w.last_search = nil
        w.searching_forward = nil
        w.search_start_marker = nil
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
    set_http_options(view)
    attach_webview_signals(view, w)
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

-- vim: ft=lua:et:sw=4:ts=8:sts=4:tw=80
