-----------------
-- Keybindings --
-----------------

-- Binding aliases
local key, buf, but = lousy.bind.key, lousy.bind.buf, lousy.bind.but
local cmd, any = lousy.bind.cmd, lousy.bind.any

-- Util aliases
local match, join = string.match, lousy.util.table.join
local strip, split = lousy.util.string.strip, lousy.util.string.split

-- Globals or defaults that are used in binds
local scroll_step = globals.scroll_step or 20
local more, less = "+"..scroll_step.."px", "-"..scroll_step.."px"
local zoom_step = globals.zoom_step or 0.1
local homepage = globals.homepage or "http://luakit.org"

-- Add binds to a mode
function add_binds(mode, binds, before)
    assert(binds and type(binds) == "table", "invalid binds table type: " .. type(binds))
    mode = type(mode) ~= "table" and {mode} or mode
    for _, m in ipairs(mode) do
        local mdata = get_mode(m)
        if mdata and before then
            mdata.binds = join(binds, mdata.binds or {})
        elseif mdata then
            mdata.binds = mdata.binds or {}
            for _, b in ipairs(binds) do table.insert(mdata.binds, b) end
        else
            new_mode(m, { binds = binds })
        end
    end
end

-- Add commands to command mode
function add_cmds(cmds, before)
    assert(cmds and type(cmds) == "table", "invalid cmds table type: " .. type(cmds))
    local mdata = get_mode("command")
    if mdata and before then
        mdata.commands = join(cmds, mdata.commands or {})
    elseif mdata then
        mdata.commands = join(mdata.commands or {}, cmds)
    else
        new_mode("command", { commands = cmds })
    end
end

-- Adds the default menu widget bindings to a mode
menu_binds = {
    -- Navigate items
    key({},          "j",       function (w) w.menu:move_down() end),
    key({},          "k",       function (w) w.menu:move_up()   end),
    key({},          "Down",    function (w) w.menu:move_down() end),
    key({},          "Up",      function (w) w.menu:move_up()   end),
    key({},          "Tab",     function (w) w.menu:move_down() end),
    key({"Shift"},   "Tab",     function (w) w.menu:move_up()   end),
}

-- Add binds to special mode "all" which adds its binds to all modes.
add_binds("all", {
    key({},          "Escape",  function (w) w:set_mode() end),
    key({"Control"}, "[",       function (w) w:set_mode() end),
})

add_binds("normal", {
    -- Autoparse the `[count]` before a binding and re-call the hit function
    -- with the count removed and added to the opts table.
    any(function (w, m)
        local count, buf
        if m.buffer then
            count = string.match(m.buffer, "^(%d+)")
        end
        if count then
            buf = string.sub(count, #count + 1, (m.updated_buf and -2) or -1)
            local opts = join(m, {count = tostring(count)})
            opts.buffer = (#buf > 0 and buf) or nil
            if lousy.bind.hit(w, m.binds, m.mods, m.key, opts) then
                return true
            end
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
    key({},          "^",           function (w) w:scroll_horiz("0%") end),
    key({},          "$",           function (w) w:scroll_horiz("100%") end),
    key({"Control"}, "e",           function (w) w:scroll_vert(more)  end),
    key({"Control"}, "y",           function (w) w:scroll_vert(less)  end),
    key({"Control"}, "d",           function (w) w:scroll_page(0.5)   end),
    key({"Control"}, "u",           function (w) w:scroll_page(-0.5)  end),
    key({"Control"}, "f",           function (w) w:scroll_page(1.0)   end),
    key({"Control"}, "b",           function (w) w:scroll_page(-1.0)  end),
    key({},          "space",       function (w) w:scroll_page(1.0)   end),
    key({"Shift"},   "space",       function (w) w:scroll_page(-1.0)  end),
    key({},          "BackSpace",   function (w) w:scroll_page(-1.0)  end),

    -- Specific scroll
    buf("^gg$",                     function (w, b, m) w:scroll_vert(m.count.."%") end, {count = 0}),
    buf("^G$",                      function (w, b, m) w:scroll_vert(m.count.."%") end, {count = 100}),

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

    -- History
    key({},          "H",           function (w, m) w:back(m.count)    end),
    key({},          "L",           function (w, m) w:forward(m.count) end),
    key({},          "b",           function (w, m) w:back(m.count)    end),
    key({},          "XF86Back",    function (w, m) w:back(m.count)    end),
    key({},          "XF86Forward", function (w, m) w:forward(m.count) end),
    key({"Control"}, "o",           function (w, m) w:back(m.count)    end),
    key({"Control"}, "i",           function (w, m) w:forward(m.count) end),

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

    key({},          "<",           function (w, m) w.tabs:reorder(w:get_current(), w.tabs:current() - m.count) end, {count=1}),
    key({},          ">",           function (w, m) w.tabs:reorder(w:get_current(), (w.tabs:current() + m.count) % w.tabs:count()) end, {count=1}),
    key({"Mod1"},    "Page_Up",     function (w, m) w.tabs:reorder(w:get_current(), w.tabs:current() - m.count) end, {count=1}),
    key({"Mod1"},    "Page_Down",   function (w, m) w.tabs:reorder(w:get_current(), (w.tabs:current() + m.count) % w.tabs:count()) end, {count=1}),

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

    -- Mouse bindings
    but({},          8,             function (w) w:back()     end),
    but({},          9,             function (w) w:forward()  end),
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

    -- Enter passthrough mode
    key({"Control"}, "z",           function (w) w:set_mode("passthrough") end),
})

add_binds("insert", {
    key({"Control"}, "z",           function (w) w:set_mode("passthrough") end),
})

add_binds({"command", "search"}, {
    key({"Shift"},   "Insert",  function (w) w:insert_cmd(luakit.get_selection()) end),
    key({"Control"}, "w",       function (w) w:del_word() end),
    key({"Control"}, "u",       function (w) w:del_line() end),
    key({"Control"}, "a",       function (w) w:beg_line() end),
    key({"Control"}, "e",       function (w) w:end_line() end),
    key({"Control"}, "f",       function (w) w:forward_char() end),
    key({"Control"}, "b",       function (w) w:backward_char() end),
    key({"Mod1"},    "f",       function (w) w:forward_word() end),
    key({"Mod1"},    "b",       function (w) w:backward_word() end),
})

-- Switching tabs with Mod1+{1,2,3,...}
mod1binds = {}
for i=1,10 do
    table.insert(mod1binds,
        key({"Mod1"}, tostring(i % 10), function (w) w.tabs:switch(i) end))
end
add_binds("normal", mod1binds)

-- Command bindings which are matched in the "command" mode from text
-- entered into the input bar.
add_cmds({
 -- cmd({command, alias1, ...},         function (w, arg, opts) .. end, opts),
 -- cmd("co[mmand]",                    function (w, arg, opts) .. end, opts),
    cmd("o[pen]",                       function (w, a) w:navigate(w:search_open(a)) end),
    cmd("t[abopen]",                    function (w, a) w:new_tab(w:search_open(a)) end),
    cmd("w[inopen]",                    function (w, a) window.new{w:search_open(a)} end),
    cmd("back",                         function (w, a) w:back(tonumber(a) or 1) end),
    cmd("f[orward]",                    function (w, a) w:forward(tonumber(a) or 1) end),
    cmd("scroll",                       function (w, a) w:scroll_vert(a) end),
    cmd("q[uit]",                       function (w)    w:close_win() end),
    cmd("write",                        function (w)    w:save_session() end),
    cmd({"writequit", "wq"},            function (w)    w:save_session() w:close_win() end),
    cmd("c[lose]",                      function (w)    w:close_tab() end),
    cmd("reload",                       function (w)    w:reload() end),
    cmd("restart",                      function (w)    w:restart() end),
    cmd("print",                        function (w)    w:eval_js("print()", "rc.lua") end),
    cmd({"viewsource",  "vs" },         function (w)    w:toggle_source(true) end),
    cmd({"viewsource!", "vs!"},         function (w)    w:toggle_source() end),
    cmd("inc[rease]",                   function (w, a) w:navigate(w:inc_uri(tonumber(a) or 1)) end),
    cmd({"javascript",   "js"},         function (w, a) w:eval_js(a, "javascript") end),
    cmd("lua",                          function (w, a) assert(loadstring("return function(w) "..a.." end"))()(w) end),
    cmd("dump",                         function (w, a)
                                            local fname = string.gsub(w.win.title, '[^a-zA-Z0-9.-]', '_')..'.html' -- sanitize filename
                                            local downdir = luakit.get_special_dir("DOWNLOAD") or "."
                                            local file = a or luakit.save_file("Save file", w.win, downdir, fname)
                                            if file then
                                                local fd = assert(io.open(file, "w"), "failed to open: " .. file)
                                                local html = assert(w:eval_js("document.documentElement.outerHTML", "dump"), "Unable to get HTML")
                                                assert(fd:write(html), "unable to save html")
                                                io.close(fd)
                                                w:notify("Dumped HTML to: " .. file)
                                            end
                                        end),
    cmd({"bookmark",    "bm" },         function (w, a)
                                            local args = split(a)
                                            local uri = table.remove(args, 1)
                                            bookmarks.add(uri, args)
                                        end),
    cmd("bookdel",                      function (w, a) bookmarks.del(tonumber(a)) end),
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
