------------------
-- Window class --
------------------

-- Window class table
window = {}

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
        -- Tab bar widgets
        tbar = {
            layout = hbox(),
            ebox   = eventbox(),
            titles = { },
        },
        -- Status bar widgets
        sbar = {
            layout = hbox(),
            ebox   = eventbox(),
            -- Left aligned widgets
            l = {
                layout = hbox(),
                ebox   = eventbox(),
                uri    = label(),
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
        -- Input bar widgets
        ibar = {
            layout  = hbox(),
            ebox    = eventbox(),
            prompt  = label(),
            input   = entry(),
        },
    }

    -- Assemble window
    w.ebox:set_child(w.layout)
    w.win:set_child(w.ebox)

    -- Pack tab bar
    local t = w.tbar
    t.ebox:set_child(t.layout, false, false, 0)
    w.layout:pack_start(t.ebox, false, false, 0)

    -- Pack notebook
    w.layout:pack_start(w.tabs, true, true, 0)

    -- Pack left-aligned statusbar elements
    local l = w.sbar.l
    l.layout:pack_start(l.uri,    false, false, 0)
    l.layout:pack_start(l.loaded, false, false, 0)
    l.ebox:set_child(l.layout)

    -- Pack right-aligned statusbar elements
    local r = w.sbar.r
    r.layout:pack_start(r.buf,    false, false, 0)
    r.layout:pack_start(r.ssl,    false, false, 0)
    r.layout:pack_start(r.tabi,   false, false, 0)
    r.layout:pack_start(r.scroll, false, false, 0)
    r.ebox:set_child(r.layout)

    -- Pack status bar elements
    local s = w.sbar
    s.layout:pack_start(l.ebox,   false, false, 0)
    s.layout:pack_start(s.sep,    true,  true,  0)
    s.layout:pack_start(r.ebox,   false, false, 0)
    s.ebox:set_child(s.layout)
    w.layout:pack_start(s.ebox,   false, false, 0)

    -- Pack input bar
    local i = w.ibar
    i.layout:pack_start(i.prompt, false, false, 0)
    i.layout:pack_start(i.input,  true,  true,  0)
    i.ebox:set_child(i.layout)
    w.layout:pack_start(i.ebox,    false, false, 0)

    -- Other settings
    i.input.show_frame = false
    w.tabs.show_tabs = false
    l.loaded:hide()
    l.uri.selectable = true
    r.ssl:hide()

    return w
end

-- Table of functions to call on window creation. Normally used to add signal
-- handlers to the new windows widgets.
window.init_funcs = {
    -- Attach notebook widget signals
    notebook_signals = function (w)
        w.tabs:add_signal("page-added", function (nbook, view, idx)
            w:update_tab_count(idx)
            w:update_tab_labels()
        end)
        w.tabs:add_signal("switch-page", function (nbook, view, idx)
            w:set_mode()
            w:update_tab_count(idx)
            w:update_win_title(view)
            w:update_uri(view)
            w:update_progress(view)
            w:update_tab_labels(idx)
            w:update_buf()
            w:update_ssl(view)
        end)
    end,

    last_win_check = function (w)
        w.win:add_signal("destroy", function ()
            -- call the quit function if this was the last window left
            if #luakit.windows == 0 then luakit.quit() end
        end)
    end,

    key_press_match = function (w)
        w.win:add_signal("key-press", function (_, mods, key)
            -- Reset command line completion
            if w:get_mode() == "command" and key ~= "Tab" and w.compl_start then
                w:update_uri()
                w.compl_index = 0
            end

            if w:hit(mods, key) then
                return true
            end
        end)
    end,

    apply_window_theme = function (w)
        local theme = lousy.theme.get()
        local s, i  = w.sbar, w.ibar

        -- Set foregrounds
        for wi, v in pairs({
            [s.l.uri]    = theme.uri_sbar_fg,
            [s.l.loaded] = theme.loaded_sbar_fg,
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
            [s.l.loaded] = theme.loaded_sbar_font,
            [s.r.buf]    = theme.buf_sbar_font,
            [s.r.ssl]    = theme.ssl_sbar_font,
            [s.r.tabi]   = theme.tabi_sbar_font,
            [s.r.scroll] = theme.scroll_sbar_font,
            [i.prompt]   = theme.prompt_ibar_font,
            [i.input]    = theme.input_ibar_font,
        }) do wi.font = v end
    end,
}

-- Helper functions which operate on the window widgets or structure.
window.methods = {
    -- Return the widget in the currently active tab
    get_current = function (w)       return w.tabs:atindex(w.tabs:current())       end,
    -- Check if given widget is the widget in the currently active tab
    is_current  = function (w, wi)   return w.tabs:indexof(wi) == w.tabs:current() end,

    get_tab_title = function (w, view)
        if not view then view = w:get_current() end
        return view:get_prop("title") or view.uri or "(Untitled)"
    end,

    new_tab = function (w, uri)
        local view = webview.new(w, uri)
        w.tabs:append(view)
        w:update_tab_count()
        return view
    end,

    -- Wrapper around the bind plugin's hit method
    hit = function (w, mods, key)
        local caught, newbuf = lousy.bind.hit(w.binds or {}, mods, key, w.buffer, w:is_mode("normal"), w)
        if w.win then
            w.buffer = newbuf
            w:update_buf()
        end
        return caught
    end,

    -- Wrapper around the bind plugin's match_cmd method
    match_cmd = function (w, buffer)
        return lousy.bind.match_cmd(binds.commands, buffer, w)
    end,

    -- enter command or characters into command line
    enter_cmd = function (w, cmd)
        local i = w.ibar.input
        w:set_mode("command")
        i.text = cmd
        i:set_position(-1)
    end,

    -- insert a string into the command line at the current cursor position
    insert_cmd = function (w, str)
        if not str then return end
        local i = w.ibar.input
        local text = i.text
        local pos = i:get_position()
        local left, right = string.sub(text, 1, pos), string.sub(text, pos+1)
        i.text = left .. str .. right
        i:set_position(pos + #str + 1)
    end,

    -- Command line completion of available commands
    cmd_completion = function (w)
        local i = w.ibar.input
        local s = w.sbar.l.uri
        local cmpl = {}

        -- Get last completion (is reset on key press other than <Tab>)
        if not w.compl_start or w.compl_index == 0 then
            w.compl_start = "^" .. string.sub(i.text, 2)
            w.compl_index = 1
        end

        -- Get suitable commands
        for _, b in ipairs(binds.commands) do
            for _, c in pairs(b.commands) do
                if c and string.match(c, w.compl_start) then
                    table.insert(cmpl, c)
                end
            end
        end

        table.sort(cmpl)

        if #cmpl > 0 then
            local text = ""
            for index, comp in pairs(cmpl) do
                if index == w.compl_index then
                    i.text = ":" .. comp .. " "
                    i:set_position(-1)
                end
                if text ~= "" then
                    text = text .. " | "
                end
                text = text .. comp
            end

            -- cycle through all possible completions
            if w.compl_index == #cmpl then
                w.compl_index = 1
            else
                w.compl_index = w.compl_index + 1
            end
            s.text = lousy.util.escape(text)
        end
    end,

    del_word = function (w)
        local i = w.ibar.input
        local text = i.text
        local pos = i:get_position()
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
            i:set_position(#left + 2)
        end
    end,

    del_line = function (w)
        local i = w.ibar.input
        if i.text ~= ":" then
            i.text = ":"
            i:set_position(-1)
        end
    end,

    -- Search history adding
    srch_hist_add = function (w, srch)
        if not w.srch_hist then w.srch_hist = {} end
        -- Check overflow
        local max_hist = globals.max_srch_history or 100
        if #w.srch_hist > (max_hist + 5) then
            while #w.srch_hist > max_hist do
                table.remove(w.srch_hist, 1)
            end
        end
        table.insert(w.srch_hist, srch)
    end,

    -- Search history traversing
    srch_hist_prev = function (w)
        if not w.srch_hist then w.srch_hist = {} end
        if not w.srch_hist_cursor then
            w.srch_hist_cursor = #w.srch_hist + 1
            w.srch_hist_current = w.ibar.input.text
        end
        local c = w.srch_hist_cursor - 1
        if w.srch_hist[c] then
            w.srch_hist_cursor = c
            w.ibar.input.text = w.srch_hist[c]
            w.ibar.input:set_position(-1)
        end
    end,

    srch_hist_next = function (w)
        if not w.srch_hist then w.srch_hist = {} end
        local c = (w.srch_hist_cursor or #w.srch_hist) + 1
        if w.srch_hist[c] then
            w.srch_hist_cursor = c
            w.ibar.input.text = w.srch_hist[c]
            w.ibar.input:set_position(-1)
        elseif w.srch_hist_current then
            w.srch_hist_cursor = nil
            w.ibar.input.text = w.srch_hist_current
            w.ibar.input:set_position(-1)
        end
    end,

    -- Command history adding
    cmd_hist_add = function (w, cmd)
        if not w.cmd_hist then w.cmd_hist = {} end
        -- Make sure history doesn't overflow
        local max_hist = globals.max_cmd_hist or 100
        if #w.cmd_hist > (max_hist + 5) then
            while #w.cmd_hist > max_hist do
                table.remove(w.cmd_hist, 1)
            end
        end
        table.insert(w.cmd_hist, cmd)
    end,

    -- Command history traversing
    cmd_hist_prev = function (w)
        if not w.cmd_hist then w.cmd_hist = {} end
        if not w.cmd_hist_cursor then
            w.cmd_hist_cursor = #w.cmd_hist + 1
            w.cmd_hist_current = w.ibar.input.text
        end
        local c = w.cmd_hist_cursor - 1
        if w.cmd_hist[c] then
            w.cmd_hist_cursor = c
            w.ibar.input.text = w.cmd_hist[c]
            w.ibar.input:set_position(-1)
        end
    end,

    cmd_hist_next = function (w)
        if not w.cmd_hist then w.cmd_hist = {} end
        local c = (w.cmd_hist_cursor or #w.cmd_hist) + 1
        if w.cmd_hist[c] then
            w.cmd_hist_cursor = c
            w.ibar.input.text = w.cmd_hist[c]
            w.ibar.input:set_position(-1)
        elseif w.cmd_hist_current then
            w.cmd_hist_cursor = nil
            w.ibar.input.text = w.cmd_hist_current
            w.ibar.input:set_position(-1)
        end
    end,

    -- GUI content update functions
    update_tab_count = function (w, i, t)
        w.sbar.r.tabi.text = string.format("[%d/%d]", i or w.tabs:current(), t or w.tabs:count())
    end,

    update_win_title = function (w, view)
        if not view then view = w:get_current() end
        local title = view:get_prop("title")
        local uri = view.uri
        if not title and not uri then
            w.win.title = "luakit"
        else
            w.win.title = (title or "luakit") .. " - " .. (uri or "about:blank")
        end
    end,

    update_uri = function (w, view, uri)
        if not view then view = w:get_current() end
        w.sbar.l.uri.text = lousy.util.escape((uri or (view and view.uri) or "about:blank"))
    end,

    update_progress = function (w, view, p)
        if not view then view = w:get_current() end
        if not p then p = view:get_prop("progress") end
        local loaded = w.sbar.l.loaded
        if not view:loading() or p == 1 then
            loaded:hide()
        else
            loaded:show()
            loaded.text = string.format("(%d%%)", p * 100)
        end
    end,

    update_scroll = function (w, view)
        if not view then view = w:get_current() end
        local scroll = w.sbar.r.scroll
        if view then
            local val, max = view:get_scroll_vert()
            if max == 0 then val = "All"
            elseif val == 0 then val = "Top"
            elseif val == max then val = "Bot"
            else val = string.format("%2d%%", (val/max) * 100)
            end
            if scroll.text ~= val then scroll.text = val end
            scroll:show()
        else
            scroll:hide()
        end
    end,

    update_ssl = function (w, view)
        if not view then view = w:get_current() end
        local trusted = view:ssl_trusted()
        local theme = lousy.theme.get()
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
        w.binds = lousy.util.table.join(binds.mode_binds[mode], binds.mode_binds.all)
        -- Clear & hide buffer
        w.buffer = nil
        w:update_buf()
    end,

    -- Tab label functions
    -- TODO: Move these functions into a module (I.e. lousy.widget.tablist)
    make_tab_label = function (w, pos)
        local theme = lousy.theme.get()
        local t = {
            label  = label(),
            sep    = eventbox(),
            ebox   = eventbox(),
            layout = hbox(),
        }
        t.label.font = theme.tab_font
        t.label:set_width(1)
        t.layout:pack_start(t.label, true,  true, 0)
        t.layout:pack_start(t.sep,   false,  false, 0)
        t.ebox:set_child(t.layout)
        t.ebox:add_signal("button-release", function (e, m, b)
            if b == 1 then
                w.tabs:switch(pos)
                return true
            elseif b == 2 then
                w:close_tab(w.tabs:atindex(pos))
                return true
            end
        end)
        return t
    end,

    destroy_tab_label = function (w, t)
        if not t then t = table.remove(w.tbar.titles) end
        -- Destroy widgets without their own windows first (I.e. labels)
        for _, wi in ipairs{ t.label, t.sep, t.ebox, t.layout } do wi:destroy() end
    end,

    update_tab_labels = function (w, current)
        local tb = w.tbar
        local count, current = w.tabs:count(), current or w.tabs:current()
        tb.ebox:hide()

        -- Leave the tablist hidden if there is only one tab open
        if count <= 1 then
            return nil
        end

        if count ~= #tb.titles then
            -- Grow the number of labels
            while count > #tb.titles do
                local t = w:make_tab_label(#tb.titles + 1)
                tb.layout:pack_start(t.ebox, true, true,  0)
                table.insert(tb.titles, t)
            end
            -- Prune number of labels
            while count < #tb.titles do
                w:destroy_tab_label()
            end
        end

        if count ~= 0 then
            for i = 1, count do
                local view = w.tabs:atindex(i)
                local t = tb.titles[i]
                local title = " " ..i.. " "..w:get_tab_title(view)
                t.label.text = lousy.util.escape(string.format("%-40s", title))
                w:apply_tablabel_theme(t, i == current)
            end
        end
        tb.ebox:show()
    end,

    -- Theme functions
    apply_tablabel_theme = function (w, t, selected)
        local theme = lousy.theme.get()
        selected = (selected and "_selected") or ""
        t.label.fg = theme[string.format("tab%s_fg", selected)]
        t.ebox.bg = theme[string.format("tab%s_bg", selected)]
    end,

    close_win = function (w)
        -- Close all tabs
        while w.tabs:count() ~= 0 do
            w:close_tab()
        end

        -- Recursively remove widgets from window
        local children = lousy.util.recursive_remove(w.win)
        -- Destroy all widgets
        for i, c in ipairs(lousy.util.table.join(children, {w.win})) do
            if c.hide then c:hide() end
            c:destroy()
        end

        -- Clear window struct
        w = setmetatable(w, {})
        for k, _ in pairs(w) do w[k] = nil end

        -- Quit if closed last window
        if #luakit.windows == 0 then luakit.quit() end
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

    -- Call window init functions
    for _, func in pairs(window.init_funcs) do
        func(w)
    end

    -- Populate notebook with tabs
    for _, uri in ipairs(uris or {}) do
        w:new_tab(uri)
    end

    -- Make sure something is loaded
    if w.tabs:count() == 0 then
        w:new_tab(globals.homepage)
    end

    -- Set initial mode
    w:set_mode()

    return w
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
