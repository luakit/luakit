-----------------
-- Keybindings --
-----------------

binds = {}

-- Binding aliases
local key, buf, but, cmd = lousy.bind.key, lousy.bind.buf, lousy.bind.but, lousy.bind.cmd
local match, join = string.match, lousy.util.table.join

-- String aliases
local strip, split = lousy.util.string.strip, lousy.util.string.split

-- Globals or defaults that are used in binds
local scroll_step = globals.scroll_step or 20
local more, less = "+"..scroll_step.."px", "-"..scroll_step.."px"
local zoom_step = globals.zoom_step or 0.1
local homepage = globals.homepage or "http://luakit.org"

-- Add key bindings to be used across all windows in the given modes.
binds.mode_binds = {
     -- buf(Pattern,                    function (w, buffer, metadata) .. end, opts),
     -- key({Modifiers}, Key name,      function (w, metadata)         .. end, opts),
     -- but({Modifiers}, Button num,    function (w, metadata)         .. end, opts),
    all = {
        key({},          "Escape",      function (w) w:set_mode() end),
        key({"Control"}, "[",           function (w) w:set_mode() end),

        but({},          8,             function (w) w:back()    end),
        but({},          9,             function (w) w:forward() end),
    },

    normal = {
        -- Autoparse the "[count]" before a buffer binding and re-call the
        -- hit function with the count removed and added to the metatable.
        buf("^%d+[^%d]",                function (w, buf, meta)
                                            local count, buf = match(buf, "^(%d+)([^%d].*)$")
                                            meta = join(meta, {count = tonumber(count)})
                                            if (#buf == 1 and lousy.bind.match_key(meta.binds, {}, buf, w, meta))
                                              or lousy.bind.match_buf(meta.binds, buf, w, meta) then
                                                return true
                                            end
                                            return false
                                        end),

        key({},          "i",           function (w) w:set_mode("insert")  end),
        key({},          ":",           function (w) w:set_mode("command") end),

        -- Scrolling
        key({},          "j",           function (w) w:scroll_vert(more)  end),
        key({},          "k",           function (w) w:scroll_vert(less)  end),
        key({},          "h",           function (w) w:scroll_horiz(less) end),
        key({},          "l",           function (w) w:scroll_horiz(more) end),
        key({"Control"}, "e",           function (w) w:scroll_vert(more)  end),
        key({"Control"}, "y",           function (w) w:scroll_vert(less)  end),
        key({"Control"}, "d",           function (w) w:scroll_page(0.5)   end),
        key({"Control"}, "u",           function (w) w:scroll_page(-0.5)  end),
        key({"Control"}, "f",           function (w) w:scroll_page(1.0)   end),
        key({"Control"}, "b",           function (w) w:scroll_page(-1.0)  end),
        key({},          "space",       function (w) w:scroll_page(1.0)   end),
        key({"Shift"},   "space",       function (w) w:scroll_page(-1.0)  end),
        key({},          "BackSpace",   function (w) w:scroll_page(-1.0)  end),
        buf("^gg$",                     function (w) w:scroll_vert("0%")  end),

        -- Specific scroll
        buf("^[%%G]$",                  function (w, b, m) w:scroll_vert(m.count.."%") end, {count = 100}),

        -- Traditional scrolling commands
        key({},          "Down",        function (w) w:scroll_vert(more)   end),
        key({},          "Up",          function (w) w:scroll_vert(less)   end),
        key({},          "Left",        function (w) w:scroll_horiz(less)  end),
        key({},          "Right",       function (w) w:scroll_horiz(more)  end),
        key({},          "Page_Down",   function (w) w:scroll_page(1.0)    end),
        key({},          "Page_Up",     function (w) w:scroll_page(-1.0)   end),
        key({},          "Home",        function (w) w:scroll_vert("0%")   end),
        key({},          "End",         function (w) w:scroll_vert("100%") end),

        -- Zooming
        key({},          "+",           function (w, m)    w:zoom_in(zoom_step  * m.count)       end, {count=1}),
        key({},          "-",           function (w, m)    w:zoom_out(zoom_step * m.count)       end, {count=1}),
        key({},          "=",           function (w, m)    w:zoom_set() end),
        buf("^zz$",                     function (w, b, m) w:zoom_set() end),
        buf("^z[iI]$",                  function (w, b, m) w:zoom_in(zoom_step  * m.count, b == "zI") end, {count=1}),
        buf("^z[oO]$",                  function (w, b, m) w:zoom_out(zoom_step * m.count, b == "zO") end, {count=1}),

        -- Specific zoom
        buf("^zZ$",                     function (w, b, m) w:zoom_set(m.count/100, true) end, {count=100}),

        -- Clipboard
        key({},          "p",           function (w)
                                            local uri = luakit.get_selection()
                                            if uri then w:navigate(w:search_open(uri)) else w:error("Empty selection.") end
                                        end),
        key({},          "P",           function (w, m)
                                            local uri = luakit.get_selection()
                                            if not uri then w:error("Empty selection.") return end
                                            for i = 1, m.count do w:new_tab(w:search_open(uri)) end
                                        end, {count = 1}),
        buf("^yy$",                     function (w) w:set_selection((w:get_current() or {}).uri or "") end),
        buf("^yt$",                     function (w) w:set_selection(w.win.title) end),

        -- Commands
        key({"Control"}, "a",           function (w)    w:navigate(w:inc_uri(1)) end),
        key({"Control"}, "x",           function (w)    w:navigate(w:inc_uri(-1)) end),
        buf("^o$",                      function (w, c) w:enter_cmd(":open ")    end),
        buf("^t$",                      function (w, c) w:enter_cmd(":tabopen ") end),
        buf("^w$",                      function (w, c) w:enter_cmd(":winopen ") end),
        buf("^O$",                      function (w, c) w:enter_cmd(":open "    .. ((w:get_current() or {}).uri or "")) end),
        buf("^T$",                      function (w, c) w:enter_cmd(":tabopen " .. ((w:get_current() or {}).uri or "")) end),
        buf("^W$",                      function (w, c) w:enter_cmd(":winopen " .. ((w:get_current() or {}).uri or "")) end),
        buf("^,g$",                     function (w, c) w:enter_cmd(":open google ") end),

        -- Searching
        key({},          "/",           function (w)    w:start_search("/")  end),
        key({},          "?",           function (w)    w:start_search("?") end),
        key({},          "n",           function (w, m)
                                            for i=1,m.count do w:search(nil, true)  end
                                            if w.search_state.ret == false then w:error("Pattern not found: " .. w.search_state.last_search) end
                                        end, {count=1}),
        key({},          "N",           function (w, m)
                                            for i=1,m.count do w:search(nil, false) end
                                            if w.search_state.ret == false then w:error("Pattern not found: " .. w.search_state.last_search) end
                                        end, {count=1}),

        -- History
        key({},          "H",           function (w, m) w:back(m.count)    end, {count=1}),
        key({},          "L",           function (w, m) w:forward(m.count) end, {count=1}),
        key({},          "b",           function (w, m) w:back(m.count)    end, {count=1}),
        key({},          "XF86Back",    function (w, m) w:back(m.count)    end, {count=1}),
        key({},          "XF86Forward", function (w, m) w:forward(m.count) end, {count=1}),
        key({"Control"}, "o",           function (w)    w:back()           end),
        key({"Control"}, "i",           function (w)    w:forward()        end),

        -- Tab
        key({"Control"}, "Page_Up",     function (w)       w:prev_tab() end),
        key({"Control"}, "Page_Down",   function (w)       w:next_tab() end),
        key({"Control"}, "Tab",         function (w)       w:next_tab() end),
        key({"Shift","Control"}, "Tab", function (w)       w:prev_tab() end),
        buf("^gT$",                     function (w, b, m) w:prev_tab(m.count) end, {count=1}),
        buf("^gt$",                     function (w, b, m) if not w:goto_tab(m.count) then w:next_tab() end end, {count=0}),

        key({"Control"}, "t",           function (w)    w:new_tab(homepage) end),
        key({"Control"}, "w",           function (w)    w:close_tab()       end),
        key({},          "d",           function (w, m) for i=1,m.count do w:close_tab()      end end, {count=1}),
        key({},          "u",           function (w, m) w:undo_close_tab(-m.count) end, {count=1}),

        key({},          "<",           function (w, m) w.tabs:reorder(w:get_current(), w.tabs:current() - m.count) end, {count=1}),
        key({},          ">",           function (w, m) w.tabs:reorder(w:get_current(), (w.tabs:current() + m.count) % w.tabs:count()) end, {count=1}),

        buf("^gH$",                     function (w, b, m) for i=1,m.count do w:new_tab(homepage) end end, {count=1}),
        buf("^gh$",                     function (w)       w:navigate(homepage) end),

        buf("^gy$",                     function (w) w:new_tab((w:get_current() or {}).history or "") end),

        key({},          "r",           function (w) w:reload() end),
        key({},          "R",           function (w) w:reload(true) end),
        key({"Control"}, "c",           function (w) w:stop() end),

        -- Config reloading
        key({"Control", "Shift"}, "R",  function (w) w:restart() end),

        -- Window
        buf("^ZZ$",                     function (w) w:save_session() w:close_win() end),
        buf("^ZQ$",                     function (w) w:close_win() end),
        buf("^D$",                      function (w) w:close_win() end),

        -- Bookmarking
        key({},          "B",           function (w)       w:enter_cmd(":bookmark " .. ((w:get_current() or {}).uri or "http://") .. " ") end),
        buf("^gb$",                     function (w)       w:navigate(bookmarks.dump_html()) end),
        buf("^gB$",                     function (w, b, m) local u = bookmarks.dump_html() for i=1,m.count do w:new_tab(u) end end, {count=1}),

        -- Quickmark open in current tab, new tabs or new window (I.e. `[count]g{onw}{a-zA-Z0-9}`)
        buf("^g[onw]%w$",               function (w, b, m)
                                            local mode, token = string.match(b, "^g(.)(.)$")
                                            local uris = lousy.util.table.clone(quickmarks.get(token) or {})
                                            for i, uri in ipairs(uris) do uris[i] = w:search_open(uri) end
                                            for c=1,m.count do
                                                if mode == "w" then
                                                    window.new(uris)
                                                else
                                                    for i, uri in ipairs(uris or {}) do
                                                        if mode == "o" and c == 1 and i == 1 then w:navigate(uri)
                                                        else w:new_tab(uri, i == 1) end
                                                    end
                                                end
                                            end
                                        end, {count=1}),
        -- Quickmark current uri (`M{a-zA-Z0-9}`)
        buf("^M%w$",                    function (w, b)
                                            local token = string.match(b, "^M(.)$")
                                            local uri = w:get_current().uri
                                            quickmarks.set(token, {uri})
                                            w:notify(string.format("Quickmarked %q: %s", token, uri))
                                        end),

        -- Mouse bindings
        but({},          2,             function (w)
                                            -- Open hovered uri in new tab
                                            local uri = w:get_current().hovered_uri
                                            if uri then
                                                w:new_tab(w:search_open(uri), false)
                                            else -- Open selection in current tab
                                                uri = luakit.get_selection()
                                                if uri then w:navigate(w:search_open(uri)) end
                                            end
                                        end),
    },

    command = {
        key({"Shift"},   "Insert",      function (w) w:insert_cmd(luakit.get_selection()) end),
        key({},          "Tab",         function (w) w:cmd_completion() end),
        key({"Control"}, "w",           function (w) w:del_word() end),
        key({"Control"}, "u",           function (w) w:del_line() end),
        key({"Control"}, "a",           function (w) w:beg_line() end),
        key({"Control"}, "e",           function (w) w:end_line() end),
        key({"Control"}, "f",           function (w) w:forward_char() end),
        key({"Control"}, "b",           function (w) w:backward_char() end),
        key({"Mod1"},    "f",           function (w) w:forward_word() end),
        key({"Mod1"},    "b",           function (w) w:backward_word() end),
    },

    search = {
        key({"Control"}, "j",           function (w) w:search(w.search_state.last_search, true) end),
        key({"Control"}, "k",           function (w) w:search(w.search_state.last_search, false) end),
    },

    qmarks = {
        -- Close menu widget
        key({},          "q",           function (w) w:set_mode() end),
        -- Navigate items
        key({},          "j",           function (w) w.menu:move_down() end),
        key({},          "k",           function (w) w.menu:move_up()   end),
        key({},          "Down",        function (w) w.menu:move_down() end),
        key({},          "Up",          function (w) w.menu:move_up()   end),
        key({},          "Tab",         function (w) w.menu:move_down() end),
        key({"Shift"},   "Tab",         function (w) w.menu:move_up()   end),
        -- Delete quickmark
        key({},          "d",           function (w)
                                            local row = w.menu:get()
                                            if row and row.qmark then
                                                quickmarks.del(row.qmark)
                                                w.menu:del()
                                            end
                                        end),
        -- Edit quickmark
        key({},          "e",           function (w)
                                            local row = w.menu:get()
                                            if row and row.qmark then
                                                local uris = quickmarks.get(row.qmark)
                                                w:enter_cmd(string.format(":qmark %s %s", row.qmark, table.concat(uris or {}, ", ")))
                                            end
                                        end),
        -- Open quickmark
        key({},          "Return",      function (w)
                                            local row = w.menu:get()
                                            if row and row.qmark then
                                                for i, uri in ipairs(quickmarks.get(row.qmark) or {}) do
                                                    uri = w:search_open(uri)
                                                    if i == 1 then w:navigate(uri) else w:new_tab(uri, false) end
                                                end
                                            end
                                        end),
        -- Open quickmark in new tab
        key({},          "t",           function (w)
                                            local row = w.menu:get()
                                            if row and row.qmark then
                                                for _, uri in ipairs(quickmarks.get(row.qmark) or {}) do
                                                    w:new_tab(w:search_open(uri), false)
                                                end
                                            end
                                        end),
        -- Open quickmark in new window
        key({},          "w",           function (w)
                                            local row = w.menu:get()
                                            w:set_mode()
                                            if row and row.qmark then
                                                window.new(quickmarks.get(row.qmark) or {})
                                            end
                                        end),
    },

    undolist = {
        -- Close menu widget
        key({},          "q",           function (w) w:set_mode() end),
        -- Navigate items
        key({},          "j",           function (w) w.menu:move_down() end),
        key({},          "k",           function (w) w.menu:move_up()   end),
        key({},          "Down",        function (w) w.menu:move_down() end),
        key({},          "Up",          function (w) w.menu:move_up()   end),
        key({},          "Tab",         function (w) w.menu:move_down() end),
        key({"Shift"},   "Tab",         function (w) w.menu:move_up()   end),
        -- Delete closed tab
        key({},          "d",           function (w)
                                            local row = w.menu:get()
                                            if row and row.uid then
                                                for i, tab in ipairs(w.closed_tabs) do
                                                    if tab.uid == row.uid then table.remove(w.closed_tabs, i) end
                                                end
                                                w.menu:del()
                                            end
                                        end),
        -- Undo multiple closed tabs
        key({},          "u",           function (w)
                                            local row = w.menu:get()
                                            if row and row.uid then
                                                for i, tab in ipairs(w.closed_tabs) do
                                                    if tab.uid == row.uid then
                                                        w:new_tab(table.remove(w.closed_tabs, i).hist, false)
                                                    end
                                                end
                                                w.menu:del()
                                            end
                                        end),
        -- Undo closed tab (in new window)
        key({},          "w",           function (w)
                                            local row = w.menu:get()
                                            w:set_mode()
                                            if row and row.uid then
                                                for i, tab in ipairs(w.closed_tabs) do
                                                    if tab.uid == row.uid then
                                                        window.new({table.remove(w.closed_tabs, i).hist})
                                                        return
                                                    end
                                                end
                                            end
                                        end),
        -- Undo closed tab
        key({},          "Return",      function (w)
                                            local row = w.menu:get()
                                            w:set_mode()
                                            if row and row.uid then
                                                for i, tab in ipairs(w.closed_tabs) do
                                                    if tab.uid == row.uid then w:undo_close_tab(i) end
                                                end
                                            end
                                        end),
    },

    insert = { },
}

-- Switching tabs with Mod1+{1,2,3,...}
for i=1,10 do
    table.insert(binds.mode_binds.normal,
        key({"Mod1"}, tostring(i % 10), function (w) w.tabs:switch(i) end))
end

-- Command bindings which are matched in the "command" mode from text
-- entered into the input bar.
binds.commands = {
 -- cmd({command, alias1, ...},         function (w, arg, opts) .. end, opts),
 -- cmd("co[mmand]",                    function (w, arg, opts) .. end, opts),
    cmd("o[pen]",                       function (w, a) w:navigate(w:search_open(a)) end),
    cmd("t[abopen]",                    function (w, a) w:new_tab(w:search_open(a)) end),
    cmd("w[inopen]",                    function (w, a) window.new{w:search_open(a)} end),
    cmd("back",                         function (w, a) w:back(tonumber(a) or 1) end),
    cmd("f[orward]",                    function (w, a) w:forward(tonumber(a) or 1) end),
    cmd("scroll",                       function (w, a) w:scroll_vert(a) end),
    cmd("q[uit]",                       function (w)    w:close_win() end),
    cmd({"wq", "writequit"},            function (w)    w:save_session() w:close_win() end),
    cmd("c[lose]",                      function (w)    w:close_tab() end),
    cmd("reload",                       function (w)    w:reload() end),
    cmd("reloadconf",                   function (w)    w:reload_config() end),
    cmd("print",                        function (w)    w:eval_js("print()", "rc.lua") end),
    cmd({"viewsource",  "vs" },         function (w)    w:toggle_source(true) end),
    cmd({"viewsource!", "vs!"},         function (w)    w:toggle_source() end),
    cmd("inc[rease]",                   function (w, a) w:navigate(w:inc_uri(tonumber(a) or 1)) end),
    cmd({"bookmark",    "bm" },         function (w, a)
                                            local args = split(a)
                                            local uri = table.remove(args, 1)
                                            bookmarks.add(uri, args)
                                        end),
    cmd("bookdel",                      function (w, a) bookmarks.del(tonumber(a)) end),

    -- Quickmark add (`:qmark f http://forum1.com, forum2.com, imdb some artist`)
    cmd("qma[rk]",                      function (w, a)
                                            local token, uris = string.match(strip(a), "^(%w)%s+(.+)$")
                                            assert(token, "invalid token")
                                            uris = split(uris, ",%s+")
                                            quickmarks.set(token, uris)
                                            w:notify(string.format("Quickmarked %q: %s", token, table.concat(uris, ", ")))
                                        end),

    -- Quickmark edit (`:qmarkedit f` -> `:qmark f furi1, furi2, ..`)
    cmd({"qme", "qmarkedit"},           function (w, a)
                                            token = strip(a)
                                            assert(#token == 1, "invalid token length: " .. token)
                                            local uris = quickmarks.get(token)
                                            w:enter_cmd(string.format(":qmark %s %s", token, table.concat(uris or {}, ", ")))
                                        end),

    -- Quickmark del (`:delqmarks b-p Aa z 4-9`)
    cmd("delqm[arks]",                  function (w, a)
                                            -- Find and del all range specifiers
                                            string.gsub(a, "(%w%-%w)", function (range)
                                                range = "["..range.."]"
                                                for _, token in ipairs(quickmarks.get_tokens()) do
                                                    if string.match(token, range) then quickmarks.del(token, false) end
                                                end
                                            end)
                                            -- Delete lone tokens
                                            string.gsub(a, "(%w)", function (token) quickmarks.del(token, false) end)
                                            quickmarks.save()
                                        end),

    -- Delete all quickmarks
    cmd({"delqm!", "delqmarks!"},       function (w) quickmarks.delall() end),

    -- View all quickmarks in an interactive menu
    cmd("qmarks",                      function (w, a)
                                            w:set_mode("qmarks")
                                            local rows = {{"Quickmarks", "URI(s)", title = true},}
                                            for _, qmark in ipairs(quickmarks.get_tokens()) do
                                                local uris = lousy.util.escape(table.concat(quickmarks.get(qmark, false), ", "))
                                                table.insert(rows, { qmark, uris, qmark = qmark})
                                            end
                                            w.menu:build(rows)
                                            w:notify("Use j/k to move, d delete, e edit, w winopen, t tabopen.", false)
                                        end),

    -- View all closed tabs in an interactive menu
    cmd("undolist",                     function (w, a)
                                            if #(w.closed_tabs) == 0 then w:notify("No closed tabs to display") return end
                                            w:set_mode("undolist")
                                            local rows = {{"Title", "URI", title = true},}
                                            for uid, tab in ipairs(w.closed_tabs) do
                                                tab.uid = uid
                                                local hi = tab.hist.items[tab.hist.index]
                                                local title, uri = lousy.util.escape(hi.title), lousy.util.escape(hi.uri)
                                                table.insert(rows, 2, { title, uri, uid = uid})
                                            end
                                            w.menu:build(rows)
                                            w:notify("Use j/k to move, d delete, w winopen.", false)
                                        end),
}

-- Helper functions which are added to the window struct
binds.helper_methods = {
    -- Navigate current view or open new tab
    navigate = function (w, uri, view)
        if not view then view = w:get_current() end
        if view then
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
        if not arg then return "about:blank" end
        args = split(strip(arg))
        -- Detect scheme:// or "." in string
        if #args == 1 and (string.match(args[1], "%.") or string.match(args[1], "^%w+://")) then
            return args[1]
        end
        -- Find search engine
        local engine = "default"
        if #args >= 1 and search_engines[args[1]] then
            engine = args[1]
            print(engine)
            table.remove(args, 1)
        end
        -- Use javascripts UTF-8 aware uri encoding function
        local terms = w:eval_js(string.format("encodeURIComponent(%q)", table.concat(args, " ")))
        -- Return search terms sub'd into search string
        return ({string.gsub(search_engines[engine], "{%d}", ({string.gsub(terms, "%%", "%%%%")})[1])})[1]
    end,

    -- Increase (or decrease) the last found number in the current uri
    inc_uri = function (w, arg)
        local uri = string.gsub(w:get_current().uri, "(%d+)([^0-9]*)$", function (num, rest)
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
            w:get_current():emit_signal("form-active")
        elseif s == "root-active" then
            w:get_current():emit_signal("root-active")
        end
    end,
}

-- Insert webview method lookup on window structure
table.insert(window.indexes, 1, function (w, k)
    -- Lookup bind helper method
    return binds.helper_methods[k]
end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
