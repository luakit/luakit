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
SCROLL_STEP      = 20
MAX_CMD_HISTORY  = 100
MAX_SRCH_HISTORY = 100
--HTTPPROXY = "http://example.com:3128"

-- Setup download directory
DOWNLOAD_DIR = luakit.get_special_dir("DOWNLOAD") or (os.getenv("HOME") .. "/downloads")

-- Per-domain webview properties
domain_props = { --[[
    ["all"] = {
        ["enable-scripts"]          = false,
        ["enable-plugins"]          = false,
        ["enable-private-browsing"] = false,
        ["user-stylesheet-uri"]     = "",
    },
    ["youtube.com"] = {
        ["enable-scripts"] = true,
        ["enable-plugins"] = true,
    },
    ["forums.archlinux.org"] = {
        ["user-stylesheet-uri"]     = luakit.data_dir .. "/styles/dark.css",
        ["enable-private-browsing"] = true,
    }, ]]
}

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

-- Small util functions
function info(...) if luakit.verbose then print(string.format(...)) end end

widget.add_signal("new", function (wi)
    wi:add_signal("init", function (wi)
        if wi.type == "window" then
            wi:add_signal("destroy", function ()
                -- Call the quit function if this was the last window left
                if #luakit.windows == 0 then luakit.quit() end
            end)
        end
    end)
end)

-- Search engines
search_engines = {
    luakit      = "http://luakit.org/search/index/luakit?q={0}",
    google      = "http://google.com/search?q={0}",
    wikipedia   = "http://en.wikipedia.org/wiki/Special:Search?search={0}",
    debbugs     = "http://bugs.debian.org/{0}",
    imdb        = "http://imdb.com/find?s=all&q={0}",
    sourceforge = "http://sf.net/search/?words={0}",
}

-- Add key bindings to be used across all windows
mode_binds = {
     -- bind.buf(Pattern,                   function (w, buffer, opts) .. end, opts),
     -- bind.key({Modifiers}, Key name,     function (w, opts)         .. end, opts),
     -- bind.but({Modifiers}, Button num,   function (w, opts)         .. end, opts),
    all = {
        bind.key({},          "Escape",     function (w) w:set_mode() end),
        bind.key({"Control"}, "[",          function (w) w:set_mode() end),

        -- Mouse bindings
        bind.but({},          2,            function (w)
                                                -- Open hovered uri in new tab
                                                local uri = w:get_current().hovered_uri
                                                if uri then w:new_tab(uri)
                                                else -- Open selection in current tab
                                                    uri = luakit.get_selection()
                                                    if uri then w:get_current().uri = uri end
                                                end
                                            end),
        bind.but({},          8,            function (w) w:back()    end),
        bind.but({},          9,            function (w) w:forward() end),
    },
    normal = {
        bind.key({},          "i",          function (w) w:set_mode("insert")  end),
        bind.key({},          ":",          function (w) w:set_mode("command") end),

        -- Scrolling
        bind.key({},          "h",          function (w) w:scroll_horiz("-"..SCROLL_STEP.."px") end),
        bind.key({},          "j",          function (w) w:scroll_vert ("+"..SCROLL_STEP.."px") end),
        bind.key({},          "k",          function (w) w:scroll_vert ("-"..SCROLL_STEP.."px") end),
        bind.key({},          "l",          function (w) w:scroll_horiz("+"..SCROLL_STEP.."px") end),
        bind.key({},          "Left",       function (w) w:scroll_horiz("-"..SCROLL_STEP.."px") end),
        bind.key({},          "Down",       function (w) w:scroll_vert ("+"..SCROLL_STEP.."px") end),
        bind.key({},          "Up",         function (w) w:scroll_vert ("-"..SCROLL_STEP.."px") end),
        bind.key({},          "Right",      function (w) w:scroll_horiz("+"..SCROLL_STEP.."px") end),
        bind.key({"Control"}, "d",          function (w) w:scroll_page(0.5) end),
        bind.key({"Control"}, "u",          function (w) w:scroll_page(-0.5) end),
        bind.key({"Control"}, "f",          function (w) w:scroll_page(1.0) end),
        bind.key({"Control"}, "b",          function (w) w:scroll_page(-1.0) end),
        bind.buf("^gg$",                    function (w) w:scroll_vert("0%")   end),
        bind.buf("^G$",                     function (w) w:scroll_vert("100%") end),
        bind.buf("^[\-\+]?[0-9]+[%%G]$",    function (w, b) w:scroll_vert(string.match(b, "^([\-\+]?%d+)[%%G]$") .. "%") end),

        -- Clipboard
        bind.key({},          "p",          function (w) w:navigate(luakit.get_selection()) end),
        bind.key({},          "P",          function (w) w:new_tab(luakit.get_selection())  end),
        bind.buf("^yy$",                    function (w) luakit.set_selection(w:get_current().uri) end),
        bind.buf("^yt$",                    function (w) luakit.set_selection(w.win.title) end),

        -- Commands
        bind.buf("^o$",                     function (w, c) w:enter_cmd(":open ") end),
        bind.buf("^t$",                     function (w, c) w:enter_cmd(":tabopen ") end),
        bind.buf("^,g$",                    function (w, c) w:enter_cmd(":websearch google ") end),

        -- Searching
        bind.key({},          "/",          function (w) w:start_search(true)  end),
        bind.key({},          "?",          function (w) w:start_search(false) end),
        bind.key({},          "n",          function (w) w:search(nil, true) end),
        bind.key({},          "N",          function (w) w:search(nil, false) end),

        -- History
        bind.buf("^[0-9]*H$",               function (w, b) w:back   (tonumber(string.match(b, "^(%d*)H$") or 1)) end),
        bind.buf("^[0-9]*L$",               function (w, b) w:forward(tonumber(string.match(b, "^(%d*)L$") or 1)) end),

        -- Tab
        bind.buf("^[0-9]*gT$",              function (w, b) w:prev_tab(tonumber(string.match(b, "^(%d*)gT$") or 1)) end),
        bind.buf("^[0-9]*gt$",              function (w, b) w:next_tab(tonumber(string.match(b, "^(%d*)gt$") or 1)) end),
        bind.buf("^gH$",                    function (w)    w:new_tab(HOMEPAGE) end),
        bind.buf("^d$",                     function (w)    w:close_tab() end),

        bind.key({},          "r",          function (w) w:reload() end),
        bind.buf("^gh$",                    function (w) w:navigate(HOMEPAGE) end),
        bind.buf("^ZZ$",                    function (w) luakit.quit() end),

        -- Link following
        bind.key({},          "f",          function (w) w:set_mode("follow") end),

    },
    command = {
        bind.key({"Shift"},   "Insert",     function (w) w:insert_cmd(luakit.get_selection()) end),
        bind.key({},          "Up",         function (w) w:cmd_hist_prev() end),
        bind.key({},          "Down",       function (w) w:cmd_hist_next() end),
        bind.key({},          "Tab",        function (w) w:cmd_completion() end),
        bind.key({"Control"}, "w",          function (w) w:del_word() end),
        bind.key({"Control"}, "u",          function (w) w:del_line() end),
    },
    search = {
        bind.key({},          "Up",         function (w) w:srch_hist_prev() end),
        bind.key({},          "Down",       function (w) w:srch_hist_next() end),
    },
    insert = { },
}

-- Commands
commands = {
 -- bind.cmd({Command, Alias1, ...},        function (w, arg, opts) .. end, opts),
    bind.cmd({"open",        "o"  },         function (w, a)    w:navigate(a) end),
    bind.cmd({"tabopen",     "t"  },         function (w, a)    w:new_tab(a) end),
    bind.cmd({"back"              },         function (w, a)    w:back(tonumber(a) or 1) end),
    bind.cmd({"forward",     "f"  },         function (w, a)    w:forward(tonumber(a) or 1) end),
    bind.cmd({"scroll"            },         function (w, a)    w:scroll_vert(a) end),
    bind.cmd({"quit",        "q"  },         function (w)       luakit.quit() end),
    bind.cmd({"close",       "c"  },         function (w)       w:close_tab() end),
    bind.cmd({"websearch",   "ws" },         function (w, e, s) w:websearch(e, s) end),
    bind.cmd({"reload",           },         function (w)       w:reload() end),
    bind.cmd({"viewsource",  "vs" },         function (w)       w:toggle_source(true) end),
    bind.cmd({"viewsource!", "vs!"},         function (w)       w:toggle_source() end),
}

function set_http_options(w)
    local proxy = HTTPPROXY or os.getenv("http_proxy")
    if proxy then w:set('proxy-uri', proxy) end
    w:set('user-agent', 'luakit')
    -- Uncomment the following options if you want to enable SSL certs validation.
    -- w:set('ssl-ca-file', '/etc/certs/ca-certificates.crt')
    -- w:set('ssl-strict', true)
end

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
    w.tabs:add_signal("page-added", function (nbook, view, idx)
        w:update_tab_count(idx)
        w:update_tab_labels()
    end)

    w.tabs:add_signal("switch-page", function (nbook, view, idx)
        w:update_tab_count(idx)
        w:update_win_title(view)
        w:update_uri(view)
        w:update_progress(view)
        w:update_tab_labels(idx)
    end)

    -- Attach window widget signals
    w.win:add_signal("key-press", function (win, mods, key)
        -- Reset command line completion
        if w:get_mode() == "command" and key ~= "Tab" and w.compl_start then
            w:update_uri()
            w.compl_index = 0
        end

        if w:hit(mods, key) then
            return true
        end
    end)

    w.win:add_signal("mode-changed", function (win, mode)
        local i, p = w.ibar.input, w.ibar.prompt

        w:update_binds(mode)
        w.cmd_hist_cursor = nil

        -- Clear following hints if the user exits follow mode
        if w.showing_hints then
            w:eval_js("clear();");
            w.showing_hints = false
        end

        -- If a user aborts a search return to the original position
        if w.search_start_marker then
            w:get_current():set_scroll_vert(w.search_start_marker)
            w.search_start_marker = nil
        end

        if mode == "normal" then
            p:hide()
            i:hide()
        elseif mode == "insert" then
            i:hide()
            i.text = ""
            p.text = "-- INSERT --"
            p:show()
        elseif mode == "command" then
            p:hide()
            i.text = ":"
            i:show()
            i:focus()
            i:set_position(-1)
        elseif mode == "search" then
            p:hide()
            i:show()
        elseif mode == "follow" then
            w:eval_js_from_file(util.find_data("scripts/follow.js"))
            w:eval_js("clear(); show_hints();")
            w.showing_hints = true
            p.text = "Follow:"
            p:show()
            i.text = ""
            i:show()
            i:focus()
            i:set_position(-1)
        else
            w.ibar.prompt.text = ""
            w.ibar.input.text = ""
        end
    end)

    -- Attach inputbar widget signals
    w.ibar.input:add_signal("changed", function()
        local text = w.ibar.input.text
        -- Auto-exit "command" mode if you backspace or delete the ":"
        -- character at the start of the input box when in "command" mode.
        if w:is_mode("command") and not string.match(text, "^:") then
            w:set_mode()
        elseif w:is_mode("search") then
            if string.match(text, "^[\?\/]") then
                w:search(string.sub(text, 2), (string.sub(text, 1, 1) == "/"))
            else
                w:clear_search()
                w:set_mode()
            end
        elseif w:is_mode("follow") then
            w:eval_js(string.format("update(%q)", w.ibar.input.text))
        end
    end)

    w.ibar.input:add_signal("activate", function()
        local text = w.ibar.input.text
        if w:is_mode("command") then
            w:cmd_hist_add(text)
            w:match_cmd(string.sub(text, 2))
            w:set_mode()
        elseif w:is_mode("search") then
            w:srch_hist_add(text)
            w:search(string.sub(text, 2), string.sub(text, 1, 1) == "/")
            -- User doesn't want to return to start position
            w.search_start_marker = nil
            w:set_mode()
            w.ibar.prompt.text = util.escape(text)
            w.ibar.prompt:show()
        end
    end)
end

-- Attach signal handlers to a new tab's webview
function attach_webview_signals(w, view)
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
            w.sbar.l.uri.text = "Link: " .. util.escape(link)
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
            local props = util.table.join(domain_props.all or {}, domain_props[domain] or {})
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
        os.execute(string.format("mkdir -p %q", DOWNLOAD_DIR))
        local dl = DOWNLOAD_DIR .. "/" .. filename
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
            new_window({ link })
            return true
        end
        w:new_tab(link)
    end)

    view:add_signal("create-web-view", function (v)
        return w:new_tab()
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
    get_current = function (w)       return w.tabs:atindex(w.tabs:current())       end,
    -- Check if given widget is the widget in the currently active tab
    is_current  = function (w, wi)   return w.tabs:indexof(wi) == w.tabs:current() end,

    -- Wrappers around the mode plugin
    set_mode    = function (w, name)    mode.set(w.win, name)                              end,
    get_mode    = function (w)          return mode.get(w.win)                             end,
    is_mode     = function (w, name)    return name == w:get_mode()                        end,
    is_any_mode = function (w, t, name) return util.table.hasitem(t, name or w:get_mode()) end,

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

    navigate = function (w, uri, view)
        local v = view or w:get_current()
        if v then
            v.uri = uri
        else
            return w:new_tab(uri)
        end
    end,

    reload = function (w, view)
        if not view then view = w:get_current() end
        view:reload()
    end,

    new_tab = function (w, uri)
        local view = webview()
        w.tabs:append(view)
        set_http_options(w)
        attach_webview_signals(w, view)
        if uri then view.uri = uri end
        view.show_scrollbars = false
        w:update_tab_count()
        return view
    end,

    -- close the current tab
    close_tab = function (w, view)
        if not view then view = w:get_current() end
        if not view then return end
        w.tabs:remove(view)
        view.uri = "about:blank"
        view:destroy()
        w:update_tab_count()
        w:update_tab_labels()
    end,

    -- evaluate javascript code and return string result
    eval_js = function (w, script, file, view)
        if not view then view = w:get_current() end
        return view:eval_js(script, file or "(buffer)")
    end,

    -- evaluate javascript code from file and return string result
    eval_js_from_file = function (w, file, view)
        local fh, err = io.open(file)
        if not fh then return error(err) end
        local script = fh:read("*a")
        fh:close()
        return w:eval_js(script, file, view)
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

    -- Toggle source view
    toggle_source = function (w, show, view)
        if not view then view = w:get_current() end
        if show == nil then show = not view:get_view_source() end
        view:set_view_source(show)
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
        if not str then return nil end
        local i = w.ibar.input
        local text = i.text
        local pos = i:get_position()
        local left, right = string.sub(text, 1, pos), string.sub(text, pos+1)
        i.text = left .. str .. right
        i:set_position(pos + #str + 1)
    end,

    -- search engine wrapper
    websearch = function (w, args)
        local sep = string.find(args, " ")
        local engine = string.sub(args, 1, sep-1)
        local search = string.sub(args, sep+1)
        if not search_engines[engine] then
            print("E: No matching search engine found:", engine)
            return 0
        end
        local uri = string.gsub(search_engines[engine], "{%d}", search)
        return w:navigate(uri)
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
        for _, b in ipairs(commands) do
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
            s.text = util.escape(text)
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
        if #w.srch_hist > ((MAX_SRCH_HISTORY or 100) + 5) then
            while #w.srch_hist > (MAX_SRCH_HISTORY or 100) do
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
        if #w.cmd_hist > ((MAX_CMD_HISTORY or 100) + 5) then
            while #w.cmd_hist > (MAX_CMD_HISTORY or 100) do
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

    -- Searching functions
    start_search = function (w, forward)
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

    search = function (w, text, forward)
        local view = w:get_current()
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

    clear_search = function (w)
        w:get_current():clear_search()
        -- Clear search state
        w.last_search = nil
        w.searching_forward = nil
        w.search_start_marker = nil
    end,

    -- Webview scroll functions
    scroll_vert = function (w, value, view)
        if not view then view = w:get_current() end
        local cur, max = view:get_scroll_vert()
        if type(value) == "string" then
            value = parse_scroll(cur, max, value)
        end
        view:set_scroll_vert(value)
    end,

    scroll_horiz = function (w, value, view)
        if not view then view = w:get_current() end
        local cur, max = view:get_scroll_horiz()
        if type(value) == "string" then
            value = parse_scroll(cur, max, value)
        end
        view:set_scroll_horiz(value)
    end,

    -- vertical scroll of a multiple of the view_size
    scroll_page = function (w, value, view)
        if not view then view = w:get_current() end
        local cur, max, size = view:get_scroll_vert()
        view:set_scroll_vert(cur + size * value)
    end,

    -- Tab traversing functions
    next_tab = function (w, n)
        w.tabs:switch((((n or 1) + w.tabs:current() -1) % w.tabs:count()) + 1)
    end,
    prev_tab = function (w, n)
        w.tabs:switch(((w.tabs:current() - (n or 1) -1) % w.tabs:count()) + 1)
    end,
    goto_tab = function (w, n)
        w.tabs:switch(n)
    end,

    -- History traversing functions
    back = function (w, n, view)
        (view or w:get_current()):go_back(n or 1)
    end,
    forward = function (w, n, view)
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
        if not title and not uri then
            w.win.title = "luakit"
        else
            w.win.title = (title or "luakit") .. " - " .. (uri or "about:blank")
        end
    end,

    update_uri = function (w, view, uri)
        if not view then view = w:get_current() end
        w.sbar.l.uri.text = util.escape((uri or (view and view.uri) or "about:blank"))
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
            w.sbar.r.buf.text = util.escape(string.format(" %-3s", w.buffer))
            w.sbar.r.buf:show()
        else
            w.sbar.r.buf:hide()
        end
    end,

    update_binds = function (w, mode)
        -- Generate the list of active key & buffer binds for this mode
        w.binds = util.table.join(mode_binds[mode], mode_binds.all)
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
        for _, wi in ipairs{ t.label, t.sep}    do wi:destroy() end
        for _, wi in ipairs{ t.ebox,  t.layout} do wi:destroy() end
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
                local t = tb.titles[i]
                local title = " " ..i.. " "..w:get_tab_title(w.tabs:atindex(i))
                t.label.text = util.escape(string.format(theme.tablabel_format or "%s", title))
                w:apply_tablabel_theme(t, i == current)
            end
        end
        tb.ebox:show()
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

-- vim: ft=lua:et:sw=4:ts=8:sts=4:tw=80
