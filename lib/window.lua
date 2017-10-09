--- Main window UI.
--
-- The window module builds the UI for each luakit window, and manages modes,
-- keybind state, and common functions like tab navigation and management.
--
-- @module window
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2012 Mason Larobina <mason.larobina@gmail.com>

require "lfs"
local lousy = require("lousy")
local settings = require("settings")
local theme = lousy.theme.get()

local _M = {}

lousy.signal.setup(_M, true)

--- Map of `window` widgets to window class tables.
-- @type table
-- @readonly
_M.bywidget = setmetatable({}, { __mode = "k" })

-- Widget construction aliases
local function entry()    return widget{type="entry"}    end
local function eventbox() return widget{type="eventbox"} end
local function hbox()     return widget{type="hbox"}     end
local function label()    return widget{type="label"}    end
local function notebook() return widget{type="notebook"} end
local function vbox()     return widget{type="vbox"}     end
local function overlay()  return widget{type="overlay"}  end

--- Construction function which will build and arrange the window's widgets.
-- @tparam table w The initial window class table.
function _M.build(w)
    -- Create a table for widgets and state variables for a window
    local ww = {
        win    = widget{type="window"},
        ebox   = eventbox(),
        layout = vbox(),
        tabs   = notebook(),
        -- Status bar widgets
        sbar = {
            layout = hbox(),
            ebox   = eventbox(),
            -- Left aligned widgets
            l = {
                layout = hbox(),
                ebox   = eventbox(),
            },
            -- Fills space between the left and right aligned widgets
            sep = eventbox(),
            -- Right aligned widgets
            r = {
                layout = hbox(),
                ebox   = eventbox(),
            },
        },

        -- Vertical menu window widget (completion results, bookmarks, qmarks, ..)
        menu = lousy.widget.menu(),
        menu_tabs = overlay(),

        -- Input bar widgets
        ibar = {
            layout  = hbox(),
            ebox    = eventbox(),
            prompt  = label(),
            input   = entry(),
            prompt_text = "",
            input_text = "",
        },
        bar_layout = vbox(),
    }

    -- Replace values in w
    for k, v in pairs(ww) do w[k] = v end

    -- Tablist widget
    w.tablist = lousy.widget.tablist(w.tabs, "horizontal")

    w.ebox.child = w.layout
    w.layout:pack(w.tablist.widget)
    w.menu_tabs.child = w.tabs

    w.win.child = w.ebox
    w.layout:pack(w.menu_tabs, { expand = true, fill = true })

    -- Pack left-aligned statusbar elements
    local l = w.sbar.l
    l.layout.homogeneous = false;
    l.ebox.child = l.layout

    -- Pack right-aligned statusbar elements
    local r = w.sbar.r
    r.layout.homogeneous = false;
    r.ebox.child = r.layout

    -- Pack status bar elements
    local s = w.sbar
    s.layout.homogeneous = false;
    s.layout:pack(l.ebox)
    s.layout:pack(s.sep, { expand = true, fill = true })
    s.layout:pack(r.ebox)
    s.ebox.child = s.layout
    w.bar_layout:pack(s.ebox)

    -- Pack menu widget
    w.menu_tabs:pack(w.menu.widget, { halign = "fill", valign = "end" })
    w.menu:hide()

    -- Pack input bar
    local i = w.ibar
    i.layout.homogeneous = false;
    i.layout:pack(i.prompt)
    i.layout:pack(i.input, { expand = true, fill = true })
    i.ebox.child = i.layout
    w.bar_layout:pack(i.ebox)
    i.input.css = "border: 0;"
    i.layout.css = "transition: 0.0s ease-in-out;"
    i.input.css = "transition: 0.0s ease-in-out;"

    w.layout:pack(w.bar_layout)

    -- Other settings
    i.input.show_frame = false
    w.tabs.show_tabs = false
    w.sbar.layout.margin_left = 3
    w.sbar.layout.margin_right = 3

    -- Allow error messages to be copied
    -- TODO: *only* allow copying when showing an error
    w.ibar.prompt.selectable = true

    -- Allows indexing of window struct by window widget
    _M.bywidget[w.win] = w
end

-- Table of functions to call on window creation. Normally used to add signal
-- handlers to the new windows widgets.
local init_funcs = {
    -- Attach notebook widget signals
    notebook_signals = function (w)
        w.tabs:add_signal("switch-page", function ()
            w:set_mode()
            w.view = nil
            -- Update widgets after tab switch
            luakit.idle_add(function ()
                -- Cancel if window already destroyed
                if not w.win then return end
                w.view:emit_signal("switched-page")
                w:update_win_title()
            end)
        end)
    end,

    last_win_check = function (w)
        w.win:add_signal("destroy", function ()
            -- call the quit function if this was the last window left
            if #luakit.windows == 0 then luakit.quit() end
            if w.close_win then w:close_win() end
        end)
    end,

    key_press_match = function (w)
        w.win:add_signal("key-press", function (_, mods, key)
            -- Match & exec a bind
            local success, match = xpcall(
                function () return w:hit(mods, key) end,
                function (err) w:error(debug.traceback(err, 3)) end)

            if success and match then
                return true
            end
        end)
    end,

    tablist_tab_click = function (w)
        w.tablist:add_signal("tab-clicked", function (_, index, _, button)
            if button == 1 then
                w.tabs:switch(index)
                return true
            elseif button == 2 then
                w:close_tab(w.tabs[index])
                return true
            end
        end)
    end,

    apply_window_theme = function (w)
        local s, i = w.sbar, w.ibar

        -- Set foregrounds
        for wi, v in pairs({
            [i.prompt]   = theme.prompt_ibar_fg,
            [i.input]    = theme.input_ibar_fg,
        }) do wi.fg = v end

        -- Set backgrounds
        for wi, v in pairs({
            [s.l.ebox]   = theme.sbar_bg,
            [s.r.ebox]   = theme.sbar_bg,
            [s.sep]      = theme.sbar_bg,
            [s.ebox]     = theme.sbar_bg,
            [i.ebox]     = theme.ibar_bg,
            [i.input]    = theme.input_ibar_bg,
        }) do wi.bg = v end

        -- Set fonts
        for wi, v in pairs({
            [i.prompt]   = theme.prompt_ibar_font,
            [i.input]    = theme.input_ibar_font,
        }) do wi.font = v end
    end,

    set_default_size = function (w)
        local size = settings.window.new_window_size
        if string.match(size, "^%d+x%d+$") then
            w.win:set_default_size(string.match(size, "^(%d+)x(%d+)$"))
        else
            msg.warn("invalid window size: %q", size)
        end
    end,

    set_window_icon = function (w)
        local path = (luakit.dev_paths and os.exists("./extras/luakit.png")) or
            os.exists(luakit.install_paths.pixmap_dir .. "/luakit.png")
        if path then w.win.icon = path end
    end,

    clear_urgency_hint = function (w)
        w.win:add_signal("focus", function ()
            w.win.urgency_hint = false
        end)
    end,

    hide_ui_on_fullscreen = function (w)
        w.win:add_signal("property::fullscreen", function (win)
            w.sbar.layout.visible = not win.fullscreen
            w:update_sbar_visibility()
            w.tablist.visible = not win.fullscreen
        end)
    end,

    check_before_closing_last_window = function (w)
        w.win:add_signal("can-close", function ()
            return w:close_win() == nil and true or false
        end)
    end,
}

--- Helper functions which operate on the window widgets or structure.
-- @type {[string]=function}
-- @readwrite
_M.methods = {
    -- Wrapper around the bind plugin's hit method
    hit = function (w, mods, key, opts)
        opts = lousy.util.table.join(opts or {}, {
            enable_buffer = w:is_mode("normal"),
            buffer = w.buffer,
        })

        local caught, newbuf = lousy.bind.hit(w, w.binds, mods, key, opts)
        if w.win then -- Check binding didn't cause window to exit
            w.buffer = newbuf
            w:update_buf()
        end
        return caught
    end,

    -- Wrapper around the bind plugin's match_cmd method
    match_cmd = function (w, buffer)
        local get_mode = require("modes").get_mode
        return lousy.bind.match_cmd(w, get_mode("command").binds, buffer)
    end,

    -- enter command or characters into command line
    enter_cmd = function (w, cmd, opts)
        w:set_mode("command")
        w:set_input(cmd, opts)
    end,

    -- run command as if typed into the command line
    run_cmd = function (w, cmd, opts)
        cmd = cmd:find("^%:") and cmd or (":" .. cmd)
        w:enter_cmd(cmd, opts)
        -- Don't append to the mode's history
        local mode, hist = w.mode, w.mode.history
        w.mode.history = nil
        w:activate()
        mode.history = hist
    end,

    -- Emulates pressing the Return key in input field
    activate = function (w)
        w.ibar.input:emit_signal("activate")
    end,

    -- Shows a notification until the next keypress of the user.
    notify = function (w, msg, set_mode)
        if set_mode ~= false then w:set_mode() end
        w:set_prompt(msg, { fg = theme.notif_fg, bg = theme.notif_bg })
    end,

    warning = function (w, msg, set_mode)
        if set_mode ~= false then w:set_mode() end
        w:set_prompt(msg, { fg = theme.warning_fg, bg = theme.warning_bg })
    end,

    error = function (w, msg, set_mode)
        if set_mode ~= false then w:set_mode() end
        w:set_prompt("Error: "..msg, { fg = theme.error_fg, bg = theme.error_bg })
    end,

    update_sbar_visibility = function (w)
        if w.ibar.prompt_text or w.ibar.input_text then
            w.ibar.ebox:show()
            w.sbar.ebox:hide()
        else
            w.ibar.ebox:hide()
            if not w.win.fullscreen then
                w.sbar.ebox:show()
            end
        end
    end,

    -- Set and display the prompt
    set_prompt = function (w, text, opts)
        local input, prompt, layout = w.ibar.input, w.ibar.prompt, w.ibar.layout
        opts = opts or {}
        prompt:hide()
        -- Set theme
        local fg, bg = opts.fg or theme.ibar_fg, opts.bg or theme.ibar_bg
        if input.fg ~= fg then input.fg = fg end
        if prompt.fg ~= fg then prompt.fg = fg end
        if layout.bg ~= bg then layout.bg = bg end
        -- Set text or remain hidden
        if text then
            prompt.text = lousy.util.escape(text)
            prompt:show()
        end
        w.ibar.prompt_text = text
        w:update_sbar_visibility()
    end,

    -- Set display and focus the input bar
    set_input = function (w, text, opts)
        local input = w.ibar.input
        opts = opts or {}
        input:hide()
        -- Set theme
        local fg, bg = opts.fg or theme.ibar_fg, opts.bg or theme.ibar_bg
        if input.fg ~= fg then input.fg = fg end
        if input.bg ~= bg then input.bg = bg end
        -- Set text or remain hidden
        if text then
            input.text = text
            input:show()
            input:focus()
            input.position = opts.pos or -1
        end
        w.ibar.input_text = text
        w:update_sbar_visibility()
    end,

    set_ibar_theme = function (w, name)
        name = name or "ok"
        local th = theme[name]
        w.ibar.input.fg = th.fg
        w.ibar.prompt.fg = th.fg
        w.ibar.layout.bg = th.bg
    end,

    update_win_title = function (w)
        local uri, title = w.view.uri, w.view.title
        title = (title or "luakit") .. ((uri and " - " .. uri) or "")
        local max = settings.window.max_title_len
        if #title > max then title = string.sub(title, 1, max) .. "..." end
        w.win.title = title
    end,

    update_buf = function () end,

    update_binds = function (w, mode)
        -- Generate the list of active key & buffer binds for this mode
        local get_mode = require("modes").get_mode
        w.binds = lousy.util.table.join((get_mode(mode) or {}).binds or {}, get_mode('all').binds or {})
        -- Clear & hide buffer
        w.buffer = nil
        w:update_buf()
    end,

    new_tab = function (w, arg, opts)
        opts = opts or {}
        assert(type(opts) == "table")
        local switch, order = opts.switch, opts.order

        -- Bit of a hack
        local webview = require("webview")

        local view
        if type(arg) == "widget" and arg.type == "webview" then
            view = arg
            local ww = webview.window(view)
            ww:detach_tab(view)
        else
            -- Make new webview widget
            view = webview.new({ private = opts.private })
        end

        w:attach_tab(view, switch, order)
        if arg and not (type(arg) == "widget" and arg.type == "webview") then
            webview.set_location(view, arg)
        end

        return view
    end,

    -- close the current tab
    close_tab = function (w, view, blank_last)
        view = view or w.view
        w:emit_signal("close-tab", view)
        w:detach_tab(view, blank_last)
        view:destroy()
    end,

    attach_tab = function (w, view, switch, order)
        local taborder = package.loaded.taborder
        -- Get tab order function
        if not order and taborder then
            order = (switch == false and taborder.default_bg)
                or taborder.default
        end
        local pos = w.tabs:insert((order and order(w, view)) or -1, view)
        if switch ~= false then w.tabs:switch(pos) end
    end,

    detach_tab = function (w, view, blank_last)
        view = view or w.view
        view.parent:remove(view)
        if settings.window.close_with_last_tab == true and w.tabs:count() == 0 then
            w:close_win()
        end
        -- Treat a blank last tab as an empty notebook (if blank_last=true)
        if blank_last ~= false and w.tabs:count() == 0 then
            w:new_tab(settings.window.new_tab_page, false)
        end
    end,

    can_quit = function (w)
        -- Ask plugins if it's OK to close last window
        local emsg = luakit.emit_signal("can-close")
        if emsg then
            assert(type(emsg) == "string", "invalid exit error message")
            w:error(string.format("Can't close luakit: %s (force close "
                .. "with :q! or :wq!)", emsg))
            return false
        else
            return true
        end
    end,

    close_win = function (w, force)
        if not force and (#luakit.windows == 1) and not w:can_quit() then
            return false
        end

        w:emit_signal("close")

        -- Close all tabs
        while w.tabs:count() ~= 0 do
            w:close_tab(nil, false)
        end

        -- Destroy tablist
        w.tablist:destroy()

        -- Remove from window index
        _M.bywidget[w.win] = nil

        -- Clear window struct
        w = setmetatable(w, {})

        -- Recursively remove widgets from window
        local children = lousy.util.recursive_remove(w.win)
        -- Destroy all widgets
        for _, c in ipairs(lousy.util.table.join(children, {w.win})) do
            if c.hide then c:hide() end
            c:destroy()
        end

        -- Remove all window table vars
        for k, _ in pairs(w) do w[k] = nil end

        -- Quit if closed last window
        if #luakit.windows == 0 then luakit.quit() end
    end,

    -- Navigate current view or open new tab
    navigate = function (w, arg, view)
        view = view or w.view
        if not view then return w:new_tab(arg) end
        require("webview").set_location(view, arg)
    end,

    -- Save, restart luakit and reload session.
    restart = function (w, force)
        if not force and not w:can_quit() then
            return false
        end

        -- Generate luakit launch command.
        local args = {({string.gsub(luakit.execpath, " ", "\\ ")})[1]}
        for _, arg in ipairs(luakit.options) do
            table.insert(args, arg)
        end

        -- Get new config path
        local conf = assert(luakit.confpath)

        -- Check config has valid syntax
        local cmd = table.concat(args, " ")
        if luakit.spawn_sync(cmd .. " -k -c " .. conf) ~= 0 then
            return w:error("Cannot restart, syntax error in configuration file: "..conf)
        end

        -- Save session.
        require("session").save()

        -- Replace current process with new luakit instance.
        luakit.exec(cmd)
    end,

    -- Intelligent open command which can detect a uri or search argument.
    search_open = function (_, arg)
        local lstring = lousy.util.string
        local match, find = string.match, string.find
        local search_engines = settings.window.search_engines

        -- Detect blank uris
        if not arg or match(arg, "^%s*$") then return settings.window.new_tab_page end

        -- Strip whitespace and split by whitespace into args table
        local args = lstring.split(lstring.strip(arg))

        -- Guess if single argument is an address, file, etc
        if #args == 1 and not search_engines[args[1]] then
            local uri = args[1]
            if uri == "about:blank" then return uri end

            -- Navigate if . or / in uri (I.e. domains, IP's, scheme://)
            if find(uri, "%.") or find(uri, "/") then return uri end

            -- Navigate if this is a javascript-uri
            if find(uri, "^javascript:") then return uri end

            -- Valid hostnames to check
            local hosts = { "localhost" }
            if settings.window.load_etc_hosts then
                hosts = lousy.util.get_etc_hosts()
            end

            -- Check hostnames
            for _, h in pairs(hosts) do
                if h == uri or match(uri, "^"..h..":%d+$") then return uri end
            end

            -- Check for file in filesystem
            if settings.window.check_filepath then
                if lfs.attributes(uri) then return "file://" .. uri end
            end
        end

        -- Find search engine (or use search_engines.default)
        local engine = "default"
        if args[1] and search_engines[args[1]] then
            engine = args[1]
            table.remove(args, 1)
        end
        local e = search_engines[engine] or "%s"

        -- URI encode search terms
        local terms = table.concat(args, " ")
        return type(e) == "string" and string.format(e, luakit.uri_encode(terms)) or e(terms)
    end,

    -- Increase (or decrease) the last found number in the current uri
    inc_uri = function (w, arg)
        local uri = string.gsub(w.view.uri, "(%d+)([^0-9]*)$", function (num, rest)
            return string.format("%0"..#num.."d", tonumber(num) + (arg or 1)) .. rest
        end)
        return uri
    end,

    -- Tab traversing functions
    next_tab = function (w, n)
        w.tabs:switch((((n or 1) + w.tabs:current() -1) % w.tabs:count()) + 1)
    end,

    prev_tab = function (w, n)
        w.tabs:switch(((w.tabs:current() - (n or 1) -1) % w.tabs:count()) + 1)
    end,

    goto_tab = function (w, n)
        if n and (n == -1 or n > 0) then
            return w.tabs:switch((n <= w.tabs:count() and n) or -1)
        end
    end,

    -- For each tab, switches to that tab and calls the given function passing
    -- it the view contained in the tab.
    each_tab = function (w, fn)
        for index = 1, w.tabs:count() do
            w:goto_tab(index)
            fn(w.tabs[index])
        end
    end,

    -- If argument is form-active or root-active, emits signal. Ignores all
    -- other signals.
    emit_form_root_active_signal = function (w, s)
        if s == "form-active" then
            w.view:emit_signal("form-active")
        elseif s == "root-active" then
            w.view:emit_signal("root-active")
        end
    end,
}

--- Ordered list of class index functions. Other classes (E.g. webview) are able
-- to add their own index functions to this list.
-- @type {function}
-- @readwrite
_M.indexes = {
    -- Find function in window.methods first
    function (_, k) return _M.methods[k] end
}

_M.add_signal("build", _M.build)

--- Create a new window table instance.
-- @tparam table args Array of initial tab arguments.
-- @treturn table The newly-created window table.
function _M.new(args)
    local w = {}
    _M.emit_signal("build", w)

    -- Set window metatable
    setmetatable(w, {
        __index = function (_, k)
            -- Call each window index function
            for _, index in ipairs(_M.indexes) do
                local v = index(w, k)
                if v then return v end
            end
        end,
    })

    -- Setup window widget for signals
    lousy.signal.setup(w)

    -- Call window init functions
    for _, func in pairs(init_funcs) do
        func(w)
    end
    _M.emit_signal("init", w)

    -- Populate notebook with tabs
    for _, arg in ipairs(args or {}) do
        if type(arg) == "string" then
            arg = w:search_open(arg)
        end
        w:new_tab(arg, false)
    end

    -- Show window
    w.win:show()

    -- Set initial mode
    w:set_mode()

    -- Make sure something is loaded
    if w.tabs:count() == 0 then
        w:new_tab(w:search_open(settings.window.home_page), false)
    end

    return w
end

--- Get the window that contains the given widget.
-- @tparam widget w The widget whose ancestor to find.
-- @treturn table|nil The window class table for the window that contains `w`,
-- or `nil` if the given widget is not contained within a window.
function _M.ancestor(w)
    repeat
        w = w.parent
    until w == nil or w.type == "window"
    return w and _M.bywidget[w] or nil
end

settings.register_settings({
    ["window.new_window_size"] = {
        type = "string",
        default = "800x600",
        validator = function (v)
            local x, y = v:match("^(%d+)x(%d+)$")
            if not x or not y then return false end
            return tonumber(x) > 0 and tonumber(y) > 0
        end,
        desc = [=[
            The size (in pixels) of newly-opened windows.

            Must be in the form `WxY`, where `W` and `H` are the width and height respectively.
        ]=],
    },
    ["window.home_page"] = {
        type = "string",
        default = "https://luakit.github.io/",
        desc = "The URI of the home page.",
    },
    ["window.new_tab_page"] = {
        type = "string",
        default = "about:blank",
        desc = "The URI to open when opening a new tab.",
    },
    ["window.close_with_last_tab"] = {
        type = "boolean",
        default = false,
        desc = "Luakit windows should close after all of their tabs are closed.",
    },
    ["window.search_engines"] = {
        type = "table",
        default = {
            duckduckgo  = "https://duckduckgo.com/?q=%s",
            github      = "https://github.com/search?q=%s",
            google      = "https://google.com/search?q=%s",
            imdb        = "http://www.imdb.com/find?s=all&q=%s",
            wikipedia   = "https://en.wikipedia.org/wiki/Special:Search?search=%s",

            default     = "https://google.com/search?q=%s",
        },
        desc = "The set of search engine shortcuts.",
    },
    ["window.scroll_step"] = {
        type = "number", min = 0,
        default = 40,
        desc = "The size (in pixels) of the scroll step.",
    },
    ["window.zoom_step"] = {
        type = "number", min = 0,
        default = 0.1,
        desc = "The size of the zoom step, expressed as a multiplicative factor.",
    },
    ["window.load_etc_hosts"] = {
        type = "boolean",
        default = true,
        desc = "Whether `/etc/hosts` should be used when parsing URIs.",
    },
    ["window.check_filepath"] = {
        type = "boolean",
        default = true,
        desc = "Whether opening a URI should check for local files.",
    },
    ["window.max_title_len"] = {
        type = "number",
        default = 80,
        desc = "The maximum length of the window title.",
    },
})

settings.migrate_global("window.new_window_size", "default_window_size")
settings.migrate_global("window.home_page", "homepage")
settings.migrate_global("window.scroll_step", "scroll_step")
settings.migrate_global("window.zoom_step", "zoom_step")
settings.migrate_global("window.load_etc_hosts", "load_etc_hosts")
settings.migrate_global("window.check_filepath", "check_filepath")
settings.migrate_global("window.max_title_len", "max_title_len")

local globals = package.loaded.globals
if globals then
    settings.window.search_engines = globals.search_engines
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
