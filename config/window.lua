------------------
-- Window class --
------------------

-- Window class table
window = {}

-- List of active windows by window widget
window.bywidget = setmetatable({}, { __mode = "k" })

-- Widget construction aliases
local function entry()    return widget{type="entry"}    end
local function eventbox() return widget{type="eventbox"} end
local function hbox()     return widget{type="hbox"}     end
local function label()    return widget{type="label"}    end
local function notebook() return widget{type="notebook"} end
local function vbox()     return widget{type="vbox"}     end

-- Build and pack window widgets
function window.build()
    -- Create a table for widgets and state variables for a window
    local w = {
        win    = widget{type="window"},
        ebox   = eventbox(),
        layout = vbox(),
        tabs   = notebook(),
        -- Tablist widget
        tablist = lousy.widget.tablist(),
        -- Status bar widgets
        sbar = {
            layout = hbox(),
            ebox   = eventbox(),
            -- Left aligned widgets
            l = {
                layout = hbox(),
                ebox   = eventbox(),
                uri    = label(),
                hist   = label(),
                loaded = label(),
            },
            -- Fills space between the left and right aligned widgets
            sep = eventbox(),
            -- Right aligned widgets
            r = {
                layout = hbox(),
                ebox   = eventbox(),
                buf    = label(),
                ssl    = label(),
                tabi   = label(),
                scroll = label(),
            },
        },

        -- Vertical menu window widget (completion results, bookmarks, qmarks, ..)
        menu = lousy.widget.menu(),

        -- Input bar widgets
        ibar = {
            layout  = hbox(),
            ebox    = eventbox(),
            prompt  = label(),
            input   = entry(),
        },
        closed_tabs = {}
    }

    -- Assemble window
    w.ebox.child = w.layout
    w.win.child = w.ebox

    -- Pack tablist
    w.layout:pack(w.tablist.widget)

    -- Pack notebook
    w.layout:pack(w.tabs, { expand = true, fill = true })

    -- Pack left-aligned statusbar elements
    local l = w.sbar.l
    l.layout:pack(l.uri)
    l.layout:pack(l.hist)
    l.layout:pack(l.loaded)
    l.ebox.child = l.layout

    -- Pack right-aligned statusbar elements
    local r = w.sbar.r
    r.layout:pack(r.buf)
    r.layout:pack(r.ssl)
    r.layout:pack(r.tabi)
    r.layout:pack(r.scroll)
    r.ebox.child = r.layout

    -- Pack status bar elements
    local s = w.sbar
    s.layout:pack(l.ebox)
    s.layout:pack(s.sep, { expand = true, fill = true })
    s.layout:pack(r.ebox)
    s.ebox.child = s.layout
    w.layout:pack(s.ebox)

    -- Pack menu widget
    w.layout:pack(w.menu.widget)
    w.menu:hide()

    -- Pack input bar
    local i = w.ibar
    i.layout:pack(i.prompt)
    i.layout:pack(i.input, { expand = true, fill = true })
    i.ebox.child = i.layout
    w.layout:pack(i.ebox)

    -- Other settings
    i.input.show_frame = false
    w.tabs.show_tabs = false
    l.loaded:hide()
    l.hist:hide()
    l.uri.selectable = true
    r.ssl:hide()

    -- Allows indexing of window struct by window widget
    window.bywidget[w.win] = w

    return w
end

-- Table of functions to call on window creation. Normally used to add signal
-- handlers to the new windows widgets.
window.init_funcs = {
    -- Attach notebook widget signals
    notebook_signals = function (w)
        w.tabs:add_signal("page-added", function (nbook, view, idx)
            luakit.idle_add(function ()
                w:update_tab_count()
                w:update_tablist()
                return false
            end)
        end)
        w.tabs:add_signal("switch-page", function (nbook, view, idx)
            w.view = nil
            w:set_mode()
            -- Update widgets after tab switch
            luakit.idle_add(function ()
                w:update_tab_count()
                w:update_win_title()
                w:update_uri()
                w:update_progress()
                w:update_tablist()
                w:update_buf()
                w:update_ssl()
                w:update_hist()
                return false
            end)
        end)
        w.tabs:add_signal("page-reordered", function (nbook, view, idx)
            w:update_tab_count()
            w:update_tablist()
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
            local success, match = pcall(w.hit, w, mods, key)
            if not success then
                w:error("In bind call: " .. match)
            elseif match then
                return true
            end
        end)
    end,

    tablist_tab_click = function (w)
        w.tablist:add_signal("tab-clicked", function (_, index, mods, button)
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
            [s.l.uri]    = theme.uri_sbar_fg,
            [s.l.hist]   = theme.hist_sbar_fg,
            [s.l.loaded] = theme.sbar_loaded_fg,
            [s.r.buf]    = theme.buf_sbar_fg,
            [s.r.tabi]   = theme.tabi_sbar_fg,
            [s.r.scroll] = theme.scroll_sbar_fg,
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
            [s.l.uri]    = theme.uri_sbar_font,
            [s.l.hist]   = theme.hist_sbar_font,
            [s.l.loaded] = theme.sbar_loaded_font,
            [s.r.buf]    = theme.buf_sbar_font,
            [s.r.ssl]    = theme.ssl_sbar_font,
            [s.r.tabi]   = theme.tabi_sbar_font,
            [s.r.scroll] = theme.scroll_sbar_font,
            [i.prompt]   = theme.prompt_ibar_font,
            [i.input]    = theme.input_ibar_font,
        }) do wi.font = v end
    end,

    set_default_size = function (w)
        local size = globals.default_window_size or "800x600"
        if string.match(size, "^%d+x%d+$") then
            w.win:set_default_size(string.match(size, "^(%d+)x(%d+)$"))
        else
            warn("E: window.lua: invalid window size: %q", size)
        end
    end,

    set_window_icon = function (w)
        local path = (luakit.dev_paths and os.exists("./extras/luakit.png")) or
            os.exists("/usr/share/pixmaps/luakit.png")
        if path then w.win.icon = path end
    end,
}

-- Helper functions which operate on the window widgets or structure.
window.methods = {
    -- Wrapper around the bind plugin's hit method
    hit = function (w, mods, key, opts)
        local opts = lousy.util.table.join(opts or {}, {
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
        return lousy.bind.match_cmd(w, get_mode("command").binds, buffer)
    end,

    -- enter command or characters into command line
    enter_cmd = function (w, cmd, opts)
        w:set_mode("command")
        w:set_input(cmd, opts)
    end,

    -- insert a string into the command line at the current cursor position
    insert_cmd = function (w, str)
        if not str then return end
        local i = w.ibar.input
        local text = i.text
        local pos = i.position
        local left, right = string.sub(text, 1, pos), string.sub(text, pos+1)
        i.text = left .. str .. right
        i.position = pos + #str
    end,

    -- Emulates pressing the Return key in input field
    activate = function (w)
        w.ibar.input:emit_signal("activate")
    end,

    del_word = function (w)
        local i = w.ibar.input
        local text = i.text
        local pos = i.position
        if text and #text > 1 and pos > 1 then
            local left, right = string.sub(text, 2, pos), string.sub(text, pos+1)
            if not string.find(left, "%s") then
                left = ""
            elseif string.find(left, "%w+%s*$") then
                left = string.sub(left, 0, string.find(left, "%w+%s*$") - 1)
            elseif string.find(left, "%W+%s*$") then
                left = string.sub(left, 0, string.find(left, "%W+%s*$") - 1)
            end
            i.text =  string.sub(text, 1, 1) .. left .. right
            i.position = #left + 1
        end
    end,

    del_line = function (w)
        local i = w.ibar.input
        if not string.match(i.text, "^[:/?]$") then
            i.text = string.sub(i.text, 1, 1)
            i.position = -1
        end
    end,

    del_backward_char = function (w)
        local i = w.ibar.input
        local text = i.text
        local pos = i.position

        if pos > 1 then
            i.text = string.sub(text, 0, pos - 1) .. string.sub(text, pos + 1)
            i.position = pos - 1
        end
    end,

    del_forward_char = function (w)
        local i = w.ibar.input
        local text = i.text
        local pos = i.position

        i.text = string.sub(text, 0, pos) .. string.sub(text, pos + 2)
        i.position = pos
    end,

    beg_line = function (w)
        local i = w.ibar.input
        i.position = 1
    end,

    end_line = function (w)
        local i = w.ibar.input
        i.position = -1
    end,

    forward_char = function (w)
        local i = w.ibar.input
        i.position = i.position + 1
    end,

    backward_char = function (w)
        local i = w.ibar.input
        local pos = i.position
        if pos > 1 then
            i.position = pos - 1
        end
    end,

    forward_word = function (w)
        local i = w.ibar.input
        local text = i.text
        local pos = i.position
        if text and #text > 1 then
            local right = string.sub(text, pos+1)
            if string.find(right, "%w+") then
                local _, move = string.find(right, "%w+")
                i.position = pos + move
            end
        end
    end,

    backward_word = function (w)
        local i = w.ibar.input
        local text = i.text
        local pos = i.position
        if text and #text > 1 and pos > 1 then
            local left = string.reverse(string.sub(text, 2, pos))
            if string.find(left, "%w+") then
                local _, move = string.find(left, "%w+")
                i.position = pos - move
            end
        end
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

    -- Set and display the prompt
    set_prompt = function (w, text, opts)
        local prompt, ebox, opts = w.ibar.prompt, w.ibar.ebox, opts or {}
        prompt:hide()
        -- Set theme
        fg, bg = opts.fg or theme.ibar_fg, opts.bg or theme.ibar_bg
        if prompt.fg ~= fg then prompt.fg = fg end
        if ebox.bg ~= bg then ebox.bg = bg end
        -- Set text or remain hidden
        if text then
            prompt.text = lousy.util.escape(text)
            prompt:show()
        end
    end,

    -- Set display and focus the input bar
    set_input = function (w, text, opts)
        local input, opts = w.ibar.input, opts or {}
        input:hide()
        -- Set theme
        fg, bg = opts.fg or theme.ibar_fg, opts.bg or theme.ibar_bg
        if input.fg ~= fg then input.fg = fg end
        if input.bg ~= bg then input.bg = bg end
        -- Set text or remain hidden
        if text then
            input.text = ""
            input:show()
            input:focus()
            input.text = text
            input.position = opts.pos or -1
        end
    end,

    -- GUI content update functions
    update_tab_count = function (w)
        w.sbar.r.tabi.text = string.format("[%d/%d]", w.tabs:current(), w.tabs:count())
    end,

    update_win_title = function (w)
        local uri, title = w.view.uri, w.view.title
        title = (title or "luakit") .. ((uri and " - " .. uri) or "")
        local max = globals.max_title_len or 80
        if #title > max then title = string.sub(title, 1, max) .. "..." end
        w.win.title = title
    end,

    update_uri = function (w, link)
        w.sbar.l.uri.text = lousy.util.escape((link and "Link: " .. link)
            or (w.view and w.view.uri) or "about:blank")
    end,

    update_progress = function (w)
        local p = w.view.progress
        local loaded = w.sbar.l.loaded
        if not w.view:loading() or p == 1 then
            loaded:hide()
        else
            loaded:show()
            loaded.text = string.format("(%d%%)", p * 100)
        end
    end,

    update_scroll = function (w)
        local scroll, label = w.view.scroll, w.sbar.r.scroll
        local y, max, text = scroll.y, scroll.ymax
        if     max == 0   then text = "All"
        elseif y   == 0   then text = "Top"
        elseif y   == max then text = "Bot"
        else text = string.format("%2d%%", (y / max) * 100)
        end
        if label.text ~= text then label.text = text end
    end,

    update_ssl = function (w)
        local trusted = w.view:ssl_trusted()
        local ssl = w.sbar.r.ssl
        if trusted ~= nil and not w.checking_ssl then
            ssl.fg = theme.notrust_fg
            ssl.text = "(nocheck)"
            ssl:show()
        elseif trusted == true then
            ssl.fg = theme.trust_fg
            ssl.text = "(trust)"
            ssl:show()
        elseif trusted == false then
            ssl.fg = theme.notrust_fg
            ssl.text = "(notrust)"
            ssl:show()
        else
            ssl:hide()
        end
    end,

    update_hist = function (w)
        local hist = w.sbar.l.hist
        local back, forward = w.view:can_go_back(), w.view:can_go_forward()
        local s = (back and "+" or "") .. (forward and "-" or "")
        if s ~= "" then
            hist.text = '['..s..']'
            hist:show()
        else
            hist:hide()
        end
    end,

    update_buf = function (w)
        local buf = w.sbar.r.buf
        if w.buffer then
            buf.text = lousy.util.escape(string.format(" %-3s", w.buffer))
            buf:show()
        else
            buf:hide()
        end
    end,

    update_binds = function (w, mode)
        -- Generate the list of active key & buffer binds for this mode
        w.binds = lousy.util.table.join((get_mode(mode) or {}).binds or {}, get_mode('all').binds or {})
        -- Clear & hide buffer
        w.buffer = nil
        w:update_buf()
    end,

    update_tablist = function (w)
        local current = w.tabs:current()
        local fg, bg, nfg, snfg = theme.tab_fg, theme.tab_bg, theme.tab_ntheme, theme.selected_ntheme
        local lfg, bfg, gfg = theme.tab_loading_fg, theme.tab_notrust_fg, theme.tab_trust_fg
        local escape = lousy.util.escape
        local tabs, tfmt = {}, ' <span foreground="%s">%s</span> %s'

        for i, view in ipairs(w.tabs.children) do
            -- Get tab number theme
            local ntheme = nfg
            if view:loading() then -- Show loading on all tabs
                ntheme = lfg
            elseif current == i then -- Show ssl trusted/untrusted on current tab
                local trusted = view:ssl_trusted()
                ntheme = snfg
                if trusted == false or (trusted ~= nil and not w.checking_ssl) then
                    ntheme = bfg
                elseif trusted then
                    ntheme = gfg
                end
            end
            local title = view.title or view.uri or "(Untitled)"
            tabs[i] = {
                title = string.format(tfmt, ntheme or fg, i, escape(title)),
                fg = (current == i and theme.tab_selected_fg) or fg,
                bg = (current == i and theme.tab_selected_bg) or bg,
            }
        end

        if #tabs < 2 then tabs, current = {}, 0 end
        w.tablist:update(tabs, current)
    end,

    new_tab = function (w, arg, switch, order)
        local view
        -- Use blank tab first
        if w.has_blank and w.tabs:count() == 1 and w.tabs[1].uri == "about:blank" then
            view = w.tabs[1]
        end
        w.has_blank = nil
        -- Make new webview widget
        if not view then
            view = webview.new(w)
            -- Get tab order function
            if not order and taborder then
                order = (switch == false and taborder.default_bg)
                    or taborder.default
            end
            pos = w.tabs:insert((order and order(w, view)) or -1, view)
            if switch ~= false then w.tabs:switch(pos) end
        end
        -- Load uri or webview history table
        if type(arg) == "string" then view.uri = arg
        elseif type(arg) == "table" then view.history = arg end
        -- Update statusbar widgets
        w:update_tab_count()
        w:update_tablist()
        return view
    end,

    -- close the current tab
    close_tab = function (w, view, blank_last)
        view = view or w.view
        -- Treat a blank last tab as an empty notebook (if blank_last=true)
        if blank_last ~= false and w.tabs:count() == 1 then
            if not view:loading() and view.uri == "about:blank" then return end
            w:new_tab("about:blank", false)
            w.has_blank = true
        end
        -- Save tab history
        local tab = {hist = view.history,}
        -- And relative location
        local index = w.tabs:indexof(view)
        if index ~= 1 then tab.after = w.tabs[index-1] end
        table.insert(w.closed_tabs, tab)
        view:destroy()
        w:update_tab_count()
        w:update_tablist()
    end,

    close_win = function (w, force)
        -- Ask plugins if it's OK to close last window
        if not force and (#luakit.windows == 1) then
            local emsg = luakit.emit_signal("can-close", w)
            if emsg then
                assert(type(emsg) == "string", "invalid exit error message")
                w:error(string.format("Can't close luakit: %s (force close "
                    .. "with :q! or :wq!)", emsg))
                return false
            end
        end

        w:emit_signal("close")

        -- Close all tabs
        while w.tabs:count() ~= 0 do
            w:close_tab(nil, false)
        end

        -- Destroy tablist
        w.tablist:destroy()

        -- Remove from window index
        window.bywidget[w.win] = nil

        -- Clear window struct
        w = setmetatable(w, {})

        -- Recursively remove widgets from window
        local children = lousy.util.recursive_remove(w.win)
        -- Destroy all widgets
        for i, c in ipairs(lousy.util.table.join(children, {w.win})) do
            if c.hide then c:hide() end
            c:destroy()
        end

        -- Remove all window table vars
        for k, _ in pairs(w) do w[k] = nil end

        -- Quit if closed last window
        if #luakit.windows == 0 then luakit.quit() end
    end,

    -- Navigate current view or open new tab
    navigate = function (w, uri, view)
        view = view or w.view
        if view then
            local js = string.match(uri, "^javascript:(.+)$")
            if js then
                return view:eval_js(luakit.uri_decode(js), "(javascript-uri)")
            end
            view.uri = uri
        else
            return w:new_tab(uri)
        end
    end,

    -- Save, restart luakit and reload session.
    restart = function (w)
        -- Generate luakit launch command.
        local args = {({string.gsub(luakit.execpath, " ", "\\ ")})[1]}
        if luakit.verbose then table.insert(args, "-v") end
        -- Relaunch without libunique bindings?
        if luakit.nounique then table.insert(args, "-U") end

        -- Get new config path
        local conf
        if luakit.confpath ~= "/etc/xdg/luakit/rc.lua" and os.exists(luakit.confpath) then
            conf = luakit.confpath
            table.insert(args, string.format("-c %q", conf))
        end

        -- Check config has valid syntax
        local cmd = table.concat(args, " ")
        if luakit.spawn_sync(cmd .. " -k") ~= 0 then
            return w:error("Cannot restart, syntax error in configuration file"..((conf and ": "..conf) or "."))
        end

        -- Save session.
        local wins = {}
        for _, w in pairs(window.bywidget) do table.insert(wins, w) end
        session.save(wins)

        -- Replace current process with new luakit instance.
        luakit.exec(cmd)
    end,

    -- Intelligent open command which can detect a uri or search argument.
    search_open = function (w, arg)
        local lstring = lousy.util.string
        local match, find = string.match, string.find

        -- Detect blank uris
        if not arg or match(arg, "^%s*$") then return "about:blank" end

        -- Strip whitespace and split by whitespace into args table
        local args = lstring.split(lstring.strip(arg))

        -- Guess if first argument is an address, search engine, file
        if #args == 1 then
            local uri = args[1]
            if uri == "about:blank" then return uri end

            -- Check if search engine name
            if search_engines[uri] then
                return string.format(search_engines[uri], "")
            end

            -- Navigate if . or / in uri (I.e. domains, IP's, scheme://)
            if find(uri, "%.") or find(uri, "/") then return uri end

            -- Navigate if this is a javascript-uri
            if find(uri, "^javascript:") then return uri end

            -- Valid hostnames to check
            local hosts = { "localhost" }
            if globals.load_etc_hosts ~= false then
                hosts = lousy.util.get_etc_hosts()
            end

            -- Check hostnames
            for _, h in pairs(hosts) do
                if h == uri or match(uri, "^"..h..":%d+$") then return uri end
            end

            -- Check for file in filesystem
            if globals.check_filepath ~= false then
                if lfs.attributes(uri) then return "file://" .. uri end
            end
        end

        -- Find search engine (or use search_engines.default)
        local engine = "default"
        if args[1] and search_engines[args[1]] then
            engine = args[1]
            table.remove(args, 1)
        end

        -- URI encode search terms
        local terms = luakit.uri_encode(table.concat(args, " "))
        return string.format(search_engines[engine], terms)
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

-- Ordered list of class index functions. Other classes (E.g. webview) are able
-- to add their own index functions to this list.
window.indexes = {
    -- Find function in window.methods first
    function (w, k) return window.methods[k] end
}

-- Create new window
function window.new(uris)
    local w = window.build()

    -- Set window metatable
    setmetatable(w, {
        __index = function (_, k)
            -- Check widget structure first
            local v = rawget(w, k)
            if v then return v end
            -- Call each window index function
            for _, index in ipairs(window.indexes) do
                v = index(w, k)
                if v then return v end
            end
        end,
    })

    -- Setup window widget for signals
    lousy.signal.setup(w)

    -- Call window init functions
    for _, func in pairs(window.init_funcs) do
        func(w)
    end

    -- Populate notebook with tabs
    for _, uri in ipairs(uris or {}) do
        w:new_tab(w:search_open(uri), false)
    end

    -- Make sure something is loaded
    if w.tabs:count() == 0 then
        w:new_tab(w:search_open(globals.homepage), false)
    end

    -- Set initial mode
    w:set_mode()

    -- Show window
    w.win:show()

    return w
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
