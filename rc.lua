-- Luakit configuration file, more information at http://luakit.org/

require("math")
require("mode")
require("bind")

-- Widget construction aliases
function eventbox() return widget{type="eventbox"} end
function hbox()     return widget{type="hbox"}     end
function label()    return widget{type="label"}    end
function notebook() return widget{type="notebook"} end
function vbox()     return widget{type="vbox"}     end
function webview()  return widget{type="webview"}  end
function window()   return widget{type="window"}   end
function entry()    return widget{type="entry"}    end

-- Variable definitions
HOMEPAGE    = "http://luakit.org/"
--HOMEPAGE  = "http://github.com/mason-larobina/luakit"
SCROLL_STEP = 20
MAX_HISTORY = 100

-- Luakit theme
theme = theme or {
    -- Default settings
    font = "monospace normal 9",
    fg   = "#fff",
    bg   = "#000",

    -- General settings
    statusbar_fg = "#fff",
    statusbar_bg = "#000",
    inputbar_fg  = "#000",
    inputbar_bg  = "#fff",

    -- Specific settings
    loaded_fg            = "#33AADD",
    tablabel_fg          = "#999",
    tablabel_bg          = "#111",
    selected_tablabel_fg = "#fff",
    selected_tablabel_bg = "#000",

    -- Enforce a minimum tab width of 30 characters to prevent longer tab
    -- titles overshadowing small tab titles when things get crowded.
    tablabel_format      = "%-30s",
}

widget.add_signal("new", function(wi)
    wi:add_signal("init", function(wi)
        if wi.type == "window" then
            wi:add_signal("destroy", function ()
                -- Call the quit function if this was the last window left
                if #luakit.windows == 0 then luakit.quit() end
            end)
        end
    end)
end)

-- Add key bindings to be used across all windows
mode_binds = {
    all = {
     -- bind.key({Modifiers}, Key name,   function (w, opts) .. end, opts),
        bind.key({},          "Escape",   function (w) w:set_mode() end),
        bind.key({"Control"}, "[",        function (w) w:set_mode() end),
    },
    normal = {
     -- bind.key({Modifiers}, Key name,   function (w, opts) .. end, opts),
        bind.key({},          "Escape",   function (w) w:set_mode() end),
        bind.key({},          "i",        function (w) w:set_mode("insert")  end),
        bind.key({},          ":",        function (w) w:set_mode("command") end),
        bind.key({},          "h",        function (w) w:scroll_horiz("-"..SCROLL_STEP.."px") end),
        bind.key({},          "j",        function (w) w:scroll_vert ("+"..SCROLL_STEP.."px") end),
        bind.key({},          "k",        function (w) w:scroll_vert ("-"..SCROLL_STEP.."px") end),
        bind.key({},          "l",        function (w) w:scroll_horiz("+"..SCROLL_STEP.."px") end),
        bind.key({},          "Left",     function (w) w:scroll_horiz("-"..SCROLL_STEP.."px") end),
        bind.key({},          "Down",     function (w) w:scroll_vert ("+"..SCROLL_STEP.."px") end),
        bind.key({},          "Up",       function (w) w:scroll_vert ("-"..SCROLL_STEP.."px") end),
        bind.key({},          "Right",    function (w) w:scroll_horiz("+"..SCROLL_STEP.."px") end),

     -- bind.buf(Pattern,                 function (w, buffer, opts) .. end, opts),
        bind.buf("^[0-9]*H$",             function (w, b) w:back   (tonumber(string.match(b, "^(%d*)H$") or 1)) end),
        bind.buf("^[0-9]*L$",             function (w, b) w:forward(tonumber(string.match(b, "^(%d*)L$") or 1)) end),
        bind.buf("^gg$",                  function (w)    w:scroll_vert("0%")   end),
        bind.buf("^G$",                   function (w)    w:scroll_vert("100%") end),
        bind.buf("^[0-9]*gT$",            function (w, b) w:prev_tab(tonumber(string.match(b, "^(%d*)gT$") or 1)) end),
        bind.buf("^[0-9]*gt$",            function (w, b) w:next_tab(tonumber(string.match(b, "^(%d*)gt$") or 1)) end),
        bind.buf("^[\-\+]?[0-9]+[%%|G]$", function (w, b) w:scroll_vert(string.match(b, "^([\-\+]?%d+)[%%G]$") .. "%") end),
        bind.buf("^gH$",                  function (w)    w:new_tab(HOMEPAGE) end),
        bind.buf("^gh$",                  function (w)    w:navigate(HOMEPAGE) end),
        bind.buf("^ZZ$",                  function (w)    luakit.quit() end),
    },
    command = {
        bind.key({},          "Up",       function (w) w:cmd_hist_prev() end),
        bind.key({},          "Down",     function (w) w:cmd_hist_next() end),
    },
    insert = { },
}

-- Commands
commands = {
 -- bind.cmd({Command, Alias1, ...},      function (w, arg, opts) .. end, opts),
    bind.cmd({"open",    "o"},            function (w, a) w:navigate(a) end),
    bind.cmd({"tabopen", "t"},            function (w, a) w:new_tab(a) end),
    bind.cmd({"back"        },            function (w, a) w:back(tonumber(a) or 1) end),
    bind.cmd({"forward", "f"},            function (w, a) w:forward(tonumber(a) or 1) end),
    bind.cmd({"scroll"      },            function (w, a) w:scroll_vert(a) end),
    bind.cmd({"quit",    "q"},            function (w)    luakit.quit() end),
}

-- Build and pack window widgets
function build_window()
    -- Create a table for widgets and state variables for a window
    local w = {
        win    = window(),
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
            filler = label(),
            -- Right aligned widgets
            r = {
                layout = hbox(),
                ebox   = eventbox(),
                buf    = label(),
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
    r.layout:pack_start(r.tabi,   false, false, 0)
    r.layout:pack_start(r.scroll, false, false, 0)
    r.ebox:set_child(r.layout)

    -- Pack status bar elements
    local s = w.sbar
    s.layout:pack_start(l.ebox,   false, false, 0)
    s.layout:pack_start(s.filler, true,  true,  0)
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

    return w
end

function attach_window_signals(w)
    -- Attach notebook widget signals
    w.tabs:add_signal("page-added", function(nbook, view, idx)
        w:update_tab_count(idx)
        w:update_tab_labels()
    end)

    w.tabs:add_signal("switch-page", function(nbook, view, idx)
        w:update_tab_count(idx)
        w:update_win_title(view)
        w:update_uri(view)
        w:update_progress(view)
        w:update_tab_labels(idx)
    end)

    -- Attach window widget signals
    w.win:add_signal("key-press", function(win, mods, key)
        if w:hit(mods, key) then
            return true
        end
    end)

    w.win:add_signal("mode-changed", function(win, mode)
        w:update_binds(mode)
        w.cmd_hist_cursor = nil

        if mode == "normal" then
            w.ibar.prompt.text = ""
            w.ibar.prompt:show()
            w.ibar.input:hide()
            w.ibar.input.text = ""
        elseif mode == "insert" then
            w.ibar.input:hide()
            w.ibar.input.text = ""
            w.ibar.prompt.text = "-- INSERT --"
            w.ibar.prompt:show()
        elseif mode == "command" then
            w.ibar.prompt:hide()
            w.ibar.prompt.text = ""
            w.ibar.input.text = ":"
            w.ibar.input:show()
            w.ibar.input:focus()
            w.ibar.input:set_position(-1)
        end
    end)

    -- Attach inputbar widget signals
    w.ibar.input:add_signal("changed", function()
        -- Auto-exit "command" mode if you backspace or delete the ":"
        -- character at the start of the input box when in "command" mode.
        if w:is_mode("command") and not string.match(w.ibar.input.text, "^:") then
            w:set_mode()
        end
    end)

    w.ibar.input:add_signal("activate", function()
        local buffer = w.ibar.input.text
        w:cmd_hist_add(buffer)
        w:match_cmd(string.sub(buffer, 2))
        w:set_mode()
    end)
end

-- Attach signal handlers to a new tab's webview
function attach_webview_signals(w, view)
    view:add_signal("title-changed", function (v)
        w:update_tab_labels()
        if w:is_current(v) then
            w:update_win_title(v)
        end
    end)

    view:add_signal("property::uri", function(v)
        w:update_tab_labels()
        if w:is_current(v) then
            w:update_uri(v)
        end
    end)

    view:add_signal("key-press", function ()
        -- Only allow key press events to hit the webview if the user is in
        -- "insert" mode.
        if not w:is_mode("insert") then
            return true
        end
    end)

    view:add_signal("load-start", function (v)
        if w:is_current(v) then
            w:update_progress(v, 0)
            w:set_mode()
        end
    end)

    view:add_signal("progress-update", function (v)
        if w:is_current(v) then
            w:update_progress(v)
        end
    end)

    view:add_signal("expose", function(v)
        if w:is_current(v) then
            w:update_scroll(v)
        end
    end)
end

-- Parses scroll amounts of the form:
--   Relative: "+20%", "-20%", "+20px", "-20px"
--   Absolute: 20, "20%", "20px"
-- And returns an absolute value.
function parse_scroll(current, max, value)
    if string.match(value, "^%d+px$") then
        return tonumber(string.match(value, "^(%d+)px$"))
    elseif string.match(value, "^%d+%%$") then
        return math.ceil(max * (tonumber(string.match(value, "^(%d+)%%$")) / 100))
    elseif string.match(value, "^[\-\+]%d+px") then
        return current + tonumber(string.match(value, "^([\-\+]%d+)px"))
    elseif string.match(value, "^[\-\+]%d+%%$") then
        return math.ceil(current + (max * (tonumber(string.match(value, "^([\-\+]%d+)%%$")) / 100)))
    else
        print("E: unable to parse scroll amount:", value)
    end
end

-- Helper functions which operate on a windows widget structure
window_helpers = {
    -- Return the widget in the currently active tab
    get_current = function(w)       return w.tabs:atindex(w.tabs:current())       end,
    -- Check if given widget is the widget in the currently active tab
    is_current  = function(w, wi)   return w.tabs:indexof(wi) == w.tabs:current() end,

    -- Wrappers around the mode plugin
    set_mode    = function(w, name)    mode.set(w.win, name)                              end,
    get_mode    = function(w)          return mode.get(w.win)                             end,
    is_mode     = function(w, name)    return name == w:get_mode()                        end,
    is_any_mode = function(w, t, name) return util.table.hasitem(t, name or w:get_mode()) end,

    -- Wrappers around the view:get_prop & view:set_prop methods
    get = function (w, prop, view)
        if not view then view = w:get_current() end
        return view:get_prop(prop)
    end,

    set = function (w, prop, val, view)
        if not view then view = w:get_current() end
        view:set_prop(prop, val)
    end,

    get_tab_title = function (w, view)
        if not view then view = w:get_current() end
        return view:get_prop("title") or view.uri or "(Untitled)"
    end,

    navigate = function(w, uri, view)
        (view or w:get_current()).uri = uri
    end,

    new_tab = function(w, uri)
        local view = webview()
        w.tabs:append(view)
        attach_webview_signals(w, view)
        if uri then view.uri = uri end
        view.show_scrollbars = false
        w:update_tab_count()
    end,

    -- Wrapper around the bind plugin's hit method
    hit = function (w, mods, key)
        local caught, newbuf = bind.hit(w.binds or {}, mods, key, w.buffer, w:is_mode("normal"), w)
        w.buffer = newbuf
        w:update_buf()
        return caught
    end,

    -- Wrapper around the bind plugin's match_cmd method
    match_cmd = function (w, buffer)
        return bind.match_cmd(commands, buffer, w)
    end,

    -- Command history adding
    cmd_hist_add = function(w, cmd)
        if not w.cmd_hist then w.cmd_hist = {} end
        -- Make sure history doesn't overflow
        if #w.cmd_hist > ((MAX_HISTORY or 100) + 5) then
            while #w.cmd_hist > (MAX_HISTORY or 100) do
                table.remove(w.cmd_hist, 1)
            end
        end
        table.insert(w.cmd_hist, cmd)
    end,

    -- Command history traversing
    cmd_hist_prev = function(w)
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

    cmd_hist_next = function(w)
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

    -- Webview scroll functions
    scroll_vert = function(w, value, view)
        if not view then view = w:get_current() end
        local cur, max = view:get_scroll_vert()
        if type(value) == "string" then
            value = parse_scroll(cur, max, value)
        end
        view:set_scroll_vert(value)
    end,

    scroll_horiz = function(w, value)
        if not view then view = w:get_current() end
        local cur, max = view:get_scroll_horiz()
        if type(value) == "string" then
            value = parse_scroll(cur, max, value)
        end
        view:set_scroll_horiz(value)
    end,

    -- Tab traversing functions
    next_tab = function(w, n)
        w.tabs:switch((((n or 1) + w.tabs:current() -1) % w.tabs:count()) + 1)
    end,
    prev_tab = function(w, n)
        w.tabs:switch(((w.tabs:current() - (n or 1) -1) % w.tabs:count()) + 1)
    end,
    goto_tab = function(w, n)
        w.tabs:switch(n)
    end,

    -- History traversing functions
    back = function(w, n, view)
        (view or w:get_current()):go_back(n or 1)
    end,
    forward = function(w, n, view)
        (view or w:get_current()):go_forward(n or 1)
    end,

    -- GUI content update functions
    update_tab_count = function (w, i, t)
        w.sbar.r.tabi.text = string.format("[%d/%d]", i or w.tabs:current(), t or w.tabs:count())
    end,

    update_win_title = function (w, view)
        if not view then view = w:get_current() end
        local title = view:get_prop("title")
        local uri = view.uri
        if not title and not uri then return "luakit" end
        return (title or "luakit") .. " - " .. (uri or "about:blank")
    end,

    update_uri = function (w, view, uri)
        if not view then view = w:get_current() end
        w.sbar.l.uri.text = (uri or view.uri or "about:blank")
    end,

    update_progress = function (w, view, p)
        if not view then view = w:get_current() end
        if not p then p = view:get_prop("progress") end
        if not view:loading() or p == 1 then
            w.sbar.l.loaded:hide()
        else
            w.sbar.l.loaded:show()
            w.sbar.l.loaded.text = string.format("(%d%%)", p * 100)
        end
    end,

    update_scroll = function (w, view)
        if not view then view = w:get_current() end
        local val, max = view:get_scroll_vert()
        if max == 0 then val = "All"
        elseif val == 0 then val = "Top"
        elseif val == max then val = "Bot"
        else val = string.format("%2d%%", (val/max) * 100)
        end
        w.sbar.r.scroll.text = val
    end,

    update_buf = function (w)
        if w.buffer then
            w.sbar.r.buf.text = string.format(" %-3s", w.buffer)
            w.sbar.r.buf:show()
        else
            w.sbar.r.buf:hide()
        end
    end,

    update_binds = function (w, mode)
        -- Generate the list of binds for this mode + all
        w.binds = util.table.clone(mode_binds[mode])
        for _, b in ipairs(mode_binds["all"]) do
            table.insert(w.binds, b)
        end
        -- Clear & hide buffer
        w.buffer = nil
        w:update_buf()
    end,

    -- Tab label functions
    make_tab_label = function (w, pos)
        local t = {
            label  = label(),
            sep    = label(),
            ebox   = eventbox(),
            layout = hbox(),
        }
        t.label.font = theme.tablabel_font or theme.font
        t.layout:pack_start(t.label, true,  true, 0)
        t.layout:pack_start(t.sep,   false,  false, 0)
        t.ebox:set_child(t.layout)
        t.ebox:add_signal("clicked", function(e) w.tabs:switch(pos) end)
        return t
    end,

    destroy_tab_label = function(w, t)
        if not t then t = table.remove(w.tbar.titles) end
        for _, wi in pairs(t) do
            wi:destroy()
        end
    end,

    update_tab_labels = function (w, current)
        local tb = w.tbar
        local count, current = w.tabs:count(), current or w.tabs:current()

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
                local t = tb.titles[i]
                local title = " " ..i.. " "..w:get_tab_title(w.tabs:atindex(i))
                t.label.text = string.format(theme.tablabel_format or "%s", title)
                w:apply_tablabel_theme(t, i == current)
            end
        end

    end,

    -- Theme functions
    apply_tablabel_theme = function (w, t, selected, atheme)
        local theme = atheme or theme
        if selected then
            t.label.fg = theme.selected_tablabel_fg or theme.tablabel_fg or theme.fg
            t.ebox.bg  = theme.selected_tablabel_bg or theme.tablabel_bg or theme.bg
        else
            t.label.fg = theme.tablabel_fg or theme.fg
            t.ebox.bg  = theme.tablabel_bg or theme.bg
        end
    end,

    apply_window_theme = function (w, atheme)
        local theme        = atheme or theme
        local s, i, t      = w.sbar, w.ibar, w.tbar
        local fg, bg, font = theme.fg, theme.bg, theme.font

        -- Set foregrounds
        for wi, v in pairs({
            [s.l.uri]    = theme.uri_fg    or theme.statusbar_fg or fg,
            [s.l.loaded] = theme.loaded_fg or theme.statusbar_fg or fg,
            [s.r.buf]    = theme.buf_fg    or theme.statusbar_fg or fg,
            [s.r.tabi]   = theme.tabi_fg   or theme.statusbar_fg or fg,
            [s.r.scroll] = theme.scroll_fg or theme.statusbar_fg or fg,
            [i.prompt]   = theme.prompt_fg or theme.inputbar_fg  or fg,
            [i.input]    = theme.input_fg  or theme.inputbar_fg  or fg,
        }) do wi.fg = v end

        -- Set backgrounds
        for wi, v in pairs({
            [s.l.ebox]   = theme.statusbar_bg or bg,
            [s.r.ebox]   = theme.statusbar_bg or bg,
            [s.ebox]     = theme.statusbar_bg or bg,
            [i.ebox]     = theme.inputbar_bg  or bg,
            [i.input]    = theme.input_bg     or theme.inputbar_bg or bg,
        }) do wi.bg = v end

        -- Set fonts
        for wi, v in pairs({
            [s.l.uri]    = theme.uri_font    or theme.statusbar_font or font,
            [s.l.loaded] = theme.loaded_font or theme.statusbar_font or font,
            [s.r.buf]    = theme.buf_font    or theme.statusbar_font or font,
            [s.r.tabi]   = theme.tabi_font   or theme.statusbar_font or font,
            [s.r.scroll] = theme.scroll_font or theme.statusbar_font or font,
            [i.prompt]   = theme.prompt_font or theme.inputbar_font or font,
            [i.input]    = theme.input_font  or theme.inputbar_font or font,
        }) do wi.font = v end
    end,
}

-- Create new window
function new_window(uris)
    local w = build_window()

    -- Pack the window table full of the common helper functions
    for k, v in pairs(window_helpers) do w[k] = v end

    attach_window_signals(w)

    -- Apply window theme
    w:apply_window_theme()

    -- Populate notebook with tabs
    for _, uri in ipairs(uris or {}) do
        w:new_tab(uri)
    end

    -- Make sure something is loaded
    if w.tabs:count() == 0 then
        w:new_tab(HOMEPAGE)
    end

    -- Set initial mode
    w:set_mode()

    return w
end

new_window(uris)
