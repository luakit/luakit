-----------------
-- Keybindings --
-----------------

binds = {}

-- Binding aliases
local key, buf, but, cmd = lousy.bind.key, lousy.bind.buf, lousy.bind.but, lousy.bind.cmd

-- Globals or defaults that are used in binds
local scroll_step = globals.scroll_step or 20
local zoom_step   = globals.zoom_step or 0.1
local homepage    = globals.homepage or "http://luakit.org"

-- Add key bindings to be used across all windows in the given modes.
binds.mode_binds = {
     -- buf(Pattern,                    function (w, buffer, opts) .. end, opts),
     -- key({Modifiers}, Key name,      function (w, opts)         .. end, opts),
     -- but({Modifiers}, Button num,    function (w, opts)         .. end, opts),
    all = {
        key({},          "Escape",      function (w) w:set_mode() end),
        key({"Control"}, "[",           function (w) w:set_mode() end),

        but({},          8,             function (w) w:back()    end),
        but({},          9,             function (w) w:forward() end),
    },
    normal = {
        key({},          "i",           function (w) w:set_mode("insert")  end),
        key({},          ":",           function (w) w:set_mode("command") end),

        -- Scrolling
        key({},          "j",           function (w) w:scroll_vert("+"..scroll_step.."px") end),
        key({},          "k",           function (w) w:scroll_vert("-"..scroll_step.."px") end),
        key({},          "h",           function (w) w:scroll_horiz("-"..scroll_step.."px") end),
        key({},          "l",           function (w) w:scroll_horiz("+"..scroll_step.."px") end),
        key({"Control"}, "d",           function (w) w:scroll_page(0.5)    end),
        key({"Control"}, "u",           function (w) w:scroll_page(-0.5)   end),
        key({"Control"}, "f",           function (w) w:scroll_page(1.0)    end),
        key({"Control"}, "b",           function (w) w:scroll_page(-1.0)   end),
        buf("^gg$",                     function (w) w:scroll_vert("0%")   end),
        buf("^G$",                      function (w) w:scroll_vert("100%") end),
        buf("^[\-\+]?[0-9]+[%%G]$",     function (w, b) w:scroll_vert(string.match(b, "^([\-\+]?%d+)[%%G]$") .. "%") end),

        -- Traditional scrolling commands
        key({},          "Down",        function (w) w:scroll_vert("+"..scroll_step.."px") end),
        key({},          "Up",          function (w) w:scroll_vert("-"..scroll_step.."px") end),
        key({},          "Left",        function (w) w:scroll_horiz("-"..scroll_step.."px") end),
        key({},          "Right",       function (w) w:scroll_horiz("+"..scroll_step.."px") end),
        key({},          "Page_Down",   function (w) w:scroll_page(1.0)    end),
        key({},          "Page_Up",     function (w) w:scroll_page(-1.0)   end),
        key({},          "Home",        function (w) w:scroll_vert("0%")   end),
        key({},          "End",         function (w) w:scroll_vert("100%") end),

        -- Zooming
        buf("^z0$",                     function (w) w:zoom_reset()        end),
        buf("^zI$",                     function (w) w:zoom_in(zoom_step)  end),
        buf("^zO$",                     function (w) w:zoom_out(zoom_step) end),
        key({"Control"}, "+",           function (w) w:zoom_in(zoom_step)  end),
        key({"Control"}, "-",           function (w) w:zoom_out(zoom_step) end),

        -- Clipboard
        key({},          "p",           function (w) w:navigate(luakit.get_selection()) end),
        key({},          "P",           function (w) w:new_tab(luakit.get_selection())  end),
        buf("^yy$",                     function (w) luakit.set_selection(w:get_current().uri) end),
        buf("^yt$",                     function (w) luakit.set_selection(w.win.title) end),

        -- Commands
        buf("^o$",                      function (w, c) w:enter_cmd(":open ") end),
        buf("^O$",                      function (w, c) w:enter_cmd(":open " .. w:get_current().uri) end),
        buf("^t$",                      function (w, c) w:enter_cmd(":tabopen ") end),
        buf("^T$",                      function (w, c) w:enter_cmd(":tabopen " .. w:get_current().uri) end),
        buf("^,g$",                     function (w, c) w:enter_cmd(":websearch google ") end),

        -- Searching
        key({},          "/",           function (w) w:start_search(true)  end),
        key({},          "?",           function (w) w:start_search(false) end),
        key({},          "n",           function (w) w:search(nil, true) end),
        key({},          "N",           function (w) w:search(nil, false) end),

        -- History
        buf("^[0-9]*H$",                function (w, b) w:back   (tonumber(string.match(b, "^(%d*)H$") or 1)) end),
        buf("^[0-9]*L$",                function (w, b) w:forward(tonumber(string.match(b, "^(%d*)L$") or 1)) end),
        key({},          "b",           function (w) w:back() end),
        key({},          "XF86Back",    function (w) w:back() end),
        key({},          "XF86Forward", function (w) w:forward() end),

        -- Tab
        key({"Control"}, "Page_Up",     function (w) w:prev_tab() end),
        key({"Control"}, "Page_Down",   function (w) w:next_tab() end),
        buf("^[0-9]*gT$",               function (w, b) w:prev_tab(tonumber(string.match(b, "^(%d*)gT$") or 1)) end),
        buf("^[0-9]*gt$",               function (w, b) w:next_tab(tonumber(string.match(b, "^(%d*)gt$") or 1)) end),
        buf("^gH$",                     function (w)    w:new_tab(homepage) end),
        buf("^d$",                      function (w)    w:close_tab() end),

        key({},          "r",           function (w) w:reload() end),
        buf("^gh$",                     function (w) w:navigate(homepage) end),
        buf("^ZZ$",                     function (w) luakit.quit() end),

        -- Link following
        key({},          "f",           function (w) w:set_mode("follow") end),

        -- Bookmarking
        key({},          "B",           function (w) w:enter_cmd(":bookmark " .. w:get_current().uri .. " ") end),
        buf("^gb$",                     function (w) w:navigate(bookmarks.dump_html()) end),
        buf("^gB$",                     function (w) w:new_tab (bookmarks.dump_html()) end),

        -- Mouse bindings
        but({},          2,             function (w)
                                            -- Open hovered uri in new tab
                                            local uri = w:get_current().hovered_uri
                                            if uri then w:new_tab(uri)
                                            else -- Open selection in current tab
                                                uri = luakit.get_selection()
                                                if uri then w:get_current().uri = uri end
                                            end
                                        end),
    },
    command = {
        key({"Shift"},   "Insert",      function (w) w:insert_cmd(luakit.get_selection()) end),
        key({},          "Up",          function (w) w:cmd_hist_prev() end),
        key({},          "Down",        function (w) w:cmd_hist_next() end),
        key({},          "Tab",         function (w) w:cmd_completion() end),
        key({"Control"}, "w",           function (w) w:del_word() end),
        key({"Control"}, "u",           function (w) w:del_line() end),
    },
    search = {
        key({},          "Up",          function (w) w:srch_hist_prev() end),
        key({},          "Down",        function (w) w:srch_hist_next() end),
    },
    insert = { },
}

-- Command bindings which are matched in the "command" mode from text
-- entered into the input bar.
binds.commands = {
 -- cmd({Command, Alias1, ...},         function (w, arg, opts) .. end, opts),
    cmd({"open",        "o"  },         function (w, a)    w:navigate(a) end),
    cmd({"tabopen",     "t"  },         function (w, a)    w:new_tab(a) end),
    cmd({"back"              },         function (w, a)    w:back(tonumber(a) or 1) end),
    cmd({"forward",     "f"  },         function (w, a)    w:forward(tonumber(a) or 1) end),
    cmd({"scroll"            },         function (w, a)    w:scroll_vert(a) end),
    cmd({"quit",        "q"  },         function (w)       luakit.quit() end),
    cmd({"close",       "c"  },         function (w)       w:close_tab() end),
    cmd({"websearch",   "ws" },         function (w, e, s) w:websearch(e, s) end),
    cmd({"reload",           },         function (w)       w:reload() end),
    cmd({"viewsource",  "vs" },         function (w)       w:toggle_source(true) end),
    cmd({"viewsource!", "vs!"},         function (w)       w:toggle_source() end),
    cmd({"bookmark",    "bm" },         function (w, a)
                                            local args = lousy.util.string.split(a)
                                            local uri = table.remove(args, 1)
                                            bookmarks.add(uri, args)
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

    -- search engine wrapper
    websearch = function (w, args)
        local sep = string.find(args, " ")
        local engine = string.sub(args, 1, sep-1)
        local search = string.sub(args, sep+1)
        search = string.gsub(search, "^%s*(.-)%s*$", "%1")
        if not search_engines[engine] then
            return error("No matching search engine found: " .. engine)
        end
        local uri = string.gsub(search_engines[engine], "{%d}", search)
        return w:navigate(uri)
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

-- vim: ft=lua:et:sw=4:ts=8:sts=4:tw=80
