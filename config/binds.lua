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
local zoom_step = globals.zoom_step or 0.1

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
    add_binds("command", cmds, before)
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
    key({}, "Escape", "Return to `normal` mode.",
        function (w) w:set_mode() end),

    key({"Control"}, "[", "Return to `normal` mode.",
        function (w) w:set_mode() end),

    -- Mouse bindings
    but({}, 8, "Go back.",
        function (w) w:back() end),

    but({}, 9, "Go forward.",
        function (w) w:forward() end),

    -- Open link in new tab or navigate to selection
    but({}, 2, [[Open link under mouse cursor in new tab or navigate to the
        contents of `luakit.selection.primary`.]],
        function (w, m)
            -- Ignore button 2 clicks in form fields
            if not m.context.editable then
                -- Open hovered uri in new tab
                local uri = w.view.hovered_uri
                if uri then
                    w:new_tab(uri, false)
                else -- Open selection in current tab
                    uri = luakit.selection.primary
                    if uri then w:navigate(w:search_open(uri)) end
                end
            end
        end),

    -- Open link in new tab when Ctrl-clicked.
    but({"Control"}, 1, "Open link under mouse cursor in new tab.",
        function (w, m)
            local uri = w.view.hovered_uri
            if uri then
                w:new_tab(uri, false)
            end
        end),

    -- Zoom binds
    but({"Control"}, 4, "Increase text zoom level.",
        function (w, m) w:zoom_in() end),

    but({"Control"}, 5, "Reduce text zoom level.",
        function (w, m) w:zoom_out() end),

    -- Horizontal mouse scroll binds
    but({"Shift"}, 4, "Scroll left.",
        function (w, m) w:scroll{ xrel = -scroll_step } end),

    but({"Shift"}, 5, "Scroll right.",
        function (w, m) w:scroll{ xrel =  scroll_step } end),
})

add_binds("normal", {
    -- Autoparse the `[count]` before a binding and re-call the hit function
    -- with the count removed and added to the opts table.
    any([[Meta-binding to detect the `^[count]` syntax. The `[count]` is parsed
        and stripped from the internal buffer string and the value assigned to
        `state.count`. Then `lousy.bind.hit()` is re-called with the modified
        buffer string & original modifier state.

        #### Example binding

            lousy.bind.key({}, "%", function (w, state)
                w:scroll{ ypct = state.count }
            end, { count = 0 })

        This binding demonstrates several concepts. Firstly that you are able to
        specify per-binding default values of `count`. In this case if the user
        types `"%"` the document will be scrolled vertically to `0%` (the top).

        If the user types `"100%"` then the document will be scrolled to `100%`
        (the bottom). All without the need to use `lousy.bind.buf` bindings
        everywhere and or using a `^(%d*)` pattern prefix on every binding which
        would like to make use of the `[count]` syntax.]],
        function (w, m)
            local count, buf
            if m.buffer then
                count = string.match(m.buffer, "^(%d+)")
            end
            if count then
                buf = string.sub(m.buffer, #count + 1, (m.updated_buf and -2) or -1)
                local opts = join(m, {count = tonumber(count)})
                opts.buffer = (#buf > 0 and buf) or nil
                if lousy.bind.hit(w, m.binds, m.mods, m.key, opts) then
                    return true
                end
            end
            return false
        end),

    key({}, "i", "Enter `insert` mode.",
        function (w) w:set_mode("insert")  end),

    key({}, ":", "Enter `command` mode.",
        function (w) w:set_mode("command") end),

    -- Scrolling
    key({}, "j", "Scroll document down.",
        function (w) w:scroll{ yrel =  scroll_step } end),

    key({}, "k", "Scroll document up.",
        function (w) w:scroll{ yrel = -scroll_step } end),

    key({}, "h", "Scroll document left.",
        function (w) w:scroll{ xrel = -scroll_step } end),

    key({}, "l", "Scroll document right.",
        function (w) w:scroll{ xrel =  scroll_step } end),

    key({}, "Down", "Scroll document down.",
        function (w) w:scroll{ yrel =  scroll_step } end),

    key({}, "Up",   "Scroll document up.",
        function (w) w:scroll{ yrel = -scroll_step } end),

    key({}, "Left", "Scroll document left.",
        function (w) w:scroll{ xrel = -scroll_step } end),

    key({}, "Right", "Scroll document right.",
        function (w) w:scroll{ xrel =  scroll_step } end),

    key({}, "^", "Scroll to the absolute left of the document.",
        function (w) w:scroll{ x =  0 } end),

    key({}, "$", "Scroll to the absolute right of the document.",
        function (w) w:scroll{ x = -1 } end),

    key({}, "0", "Scroll to the absolute left of the document.",
        function (w, m)
            if not m.count then w:scroll{ y = 0 } else return false end
        end),

    key({"Control"}, "e", "Scroll document down.",
        function (w) w:scroll{ yrel =  scroll_step } end),

    key({"Control"}, "y", "Scroll document up.",
        function (w) w:scroll{ yrel = -scroll_step } end),

    key({"Control"}, "d", "Scroll half page down.",
        function (w) w:scroll{ ypagerel =  0.5 } end),

    key({"Control"}, "u", "Scroll half page up.",
        function (w) w:scroll{ ypagerel = -0.5 } end),

    key({"Control"}, "f", "Scroll page down.",
        function (w) w:scroll{ ypagerel =  1.0 } end),

    key({"Control"}, "b", "Scroll page up.",
        function (w) w:scroll{ ypagerel = -1.0 } end),

    key({}, "space", "Scroll page down.",
        function (w) w:scroll{ ypagerel =  1.0 } end),

    key({"Shift"}, "space", "Scroll page up.",
        function (w) w:scroll{ ypagerel = -1.0 } end),

    key({}, "BackSpace", "Scroll page up.",
        function (w) w:scroll{ ypagerel = -1.0 } end),

    key({}, "Page_Down", "Scroll page down.",
        function (w) w:scroll{ ypagerel =  1.0 } end),

    key({}, "Page_Up", "Scroll page up.",
        function (w) w:scroll{ ypagerel = -1.0 } end),

    key({}, "Home", "Go to the end of the document.",
        function (w) w:scroll{ y =  0 } end),

    key({}, "End", "Go to the top of the document.",
        function (w) w:scroll{ y = -1 } end),

    -- Specific scroll
    buf("^gg$", "Go to the top of the document.",
        function (w, b, m) w:scroll{ ypct = m.count } end, {count=0}),

    buf("^G$", "Go to the bottom of the document.",
        function (w, b, m) w:scroll{ ypct = m.count } end, {count=100}),

    buf("^%%$", "Go to `[count]` percent of the document.",
        function (w, b, m) w:scroll{ ypct = m.count } end),

    -- Zooming
    key({}, "+", "Enlarge text zoom of the current page.",
        function (w, m) w:zoom_in(zoom_step * m.count) end, {count=1}),

    key({}, "-", "Reduce text zom of the current page.",
        function (w, m) w:zoom_out(zoom_step * m.count) end, {count=1}),

    key({}, "=", "Reset zoom level.",
        function (w, m) w:zoom_set() end),

    buf("^z[iI]$", [[Enlarge text zoom of current page with `zi` or `zI` to
        reduce full zoom.]],
        function (w, b, m)
            w:zoom_in(zoom_step  * m.count, b == "zI")
        end, {count=1}),

    buf("^z[oO]$", [[Reduce text zoom of current page with `zo` or `zO` to
        reduce full zoom.]],
        function (w, b, m)
            w:zoom_out(zoom_step * m.count, b == "zO")
        end, {count=1}),

    -- Zoom reset or specific zoom ([count]zZ for full content zoom)
    buf("^z[zZ]$", [[Set current page zoom to `[count]` percent with
        `[count]zz`, use `[count]zZ` to set full zoom percent.]],
        function (w, b, m)
            w:zoom_set(m.count/100, b == "zZ")
        end, {count=100}),

    -- Fullscreen
    key({}, "F11", "Toggle fullscreen mode.",
        function (w) w.win.fullscreen = not w.win.fullscreen end),

    -- Clipboard
    key({}, "p", [[Open a URL based on the current primary selection contents
        in the current tab.]],
        function (w)
            local uri = luakit.selection.primary
            if not uri then w:notify("No primary selection...") return end
            w:navigate(w:search_open(uri))
        end),

    key({}, "P", [[Open a URL based on the current primary selection contents
        in `[count=1]` new tab(s).]],
        function (w, m)
            local uri = luakit.selection.primary
            if not uri then w:notify("No primary selection...") return end
            for i = 1, m.count do w:new_tab(w:search_open(uri)) end
        end, {count = 1}),

    -- Yanking
    key({}, "y", "Yank current URI to primary selection.",
        function (w)
            local uri = string.gsub(w.view.uri or "", " ", "%%20")
            luakit.selection.primary = uri
            w:notify("Yanked uri: " .. uri)
        end),

    -- Commands
    key({"Control"}, "a", "Increment last number in URL.",
        function (w) w:navigate(w:inc_uri(1)) end),

    key({"Control"}, "x", "Decrement last number in URL.",
        function (w) w:navigate(w:inc_uri(-1)) end),

    key({}, "o", "Open one or more URLs.",
        function (w) w:enter_cmd(":open ") end),

    key({}, "t", "Open one or more URLs in a new tab.",
        function (w) w:enter_cmd(":tabopen ") end),

    key({}, "w", "Open one or more URLs in a new window.",
        function (w) w:enter_cmd(":winopen ") end),

    key({}, "O", "Open one or more URLs based on current location.",
        function (w) w:enter_cmd(":open " .. (w.view.uri or "")) end),

    key({}, "T",
        "Open one or more URLs based on current location in a new tab.",
        function (w) w:enter_cmd(":tabopen " .. (w.view.uri or "")) end),

    key({}, "W",
        "Open one or more URLs based on current locaton in a new window.",
        function (w) w:enter_cmd(":winopen " .. (w.view.uri or "")) end),

    -- History
    key({}, "H", "Go back in the browser history `[count=1]` items.",
        function (w, m) w:back(m.count) end),

    key({}, "L", "Go forward in the browser history `[count=1]` times.",
        function (w, m) w:forward(m.count) end),

    key({}, "XF86Back", "Go back in the browser history.",
        function (w, m) w:back(m.count) end),

    key({}, "XF86Forward", "Go forward in the browser history.",
        function (w, m) w:forward(m.count) end),

    key({"Control"}, "o", "Go back in the browser history.",
        function (w, m) w:back(m.count) end),

    key({"Control"}, "i", "Go forward in the browser history.",
        function (w, m) w:forward(m.count) end),

    -- Tab
    key({"Control"}, "Page_Up", "Go to previous tab.",
        function (w) w:prev_tab() end),

    key({"Control"}, "Page_Down", "Go to next tab.",
        function (w) w:next_tab() end),

    key({"Control"}, "Tab", "Go to next tab.",
        function (w) w:next_tab() end),

    key({"Shift","Control"}, "Tab", "Go to previous tab.",
        function (w) w:prev_tab() end),

    buf("^gT$", "Go to previous tab.",
        function (w) w:prev_tab() end),

    buf("^gt$", "Go to next tab (or `[count]` nth tab).",
        function (w, b, m)
            if not w:goto_tab(m.count) then w:next_tab() end
        end, {count=0}),

    buf("^g0$", "Go to first tab.",
        function (w) w:goto_tab(1) end),

    buf("^g$$", "Go to last tab.",
        function (w) w:goto_tab(-1) end),

    key({"Control"}, "t", "Open a new tab.",
        function (w) w:new_tab(globals.homepage) end),

    key({"Control"}, "w", "Close current tab.",
        function (w) w:close_tab() end),

    key({}, "d", "Close current tab (or `[count]` tabs).",
        function (w, m) for i=1,m.count do w:close_tab() end end, {count=1}),

    key({}, "<", "Reorder tab left `[count=1]` positions.",
        function (w, m)
            w.tabs:reorder(w.view, w.tabs:current() - m.count)
        end, {count=1}),

    key({}, ">", "Reorder tab right `[count=1]` positions.",
        function (w, m)
            w.tabs:reorder(w.view,
                (w.tabs:current() + m.count) % w.tabs:count())
        end, {count=1}),

    buf("^gH$", "Open homepage in new tab.",
        function (w) w:new_tab(globals.homepage) end),

    buf("^gh$", "Open homepage.",
        function (w) w:navigate(globals.homepage) end),

    buf("^gy$", "Duplicate current tab.",
        function (w) w:new_tab(w.view.history or "") end),

    key({}, "r", "Reload current tab.",
        function (w) w:reload() end),

    key({}, "R", "Reload current tab (skipping cache).",
        function (w) w:reload(true) end),

    key({"Control"}, "c", "Stop loading the current tab.",
        function (w) w.view:stop() end),

    key({"Control", "Shift"}, "R", "Restart luakit (reloading configs).",
        function (w) w:restart() end),

    -- Window
    buf("^ZZ$", "Quit and save the session.",
        function (w) w:save_session() w:close_win() end),

    buf("^ZQ$", "Quit and don't save the session.",
        function (w) w:close_win() end),

    buf("^D$",  "Quit and don't save the session.",
        function (w) w:close_win() end),

    -- Enter passthrough mode
    key({"Control"}, "z",
        "Enter `passthrough` mode, ignores all luakit keybindings.",
        function (w) w:set_mode("passthrough") end),
})

add_binds("insert", {
    key({"Control"}, "z",
        "Enter `passthrough` mode, ignores all luakit keybindings.",
        function (w) w:set_mode("passthrough") end),
})

readline_bindings = {
    key({"Shift"}, "Insert",
        "Insert contents of primary selection at cursor position.",
        function (w) w:insert_cmd(luakit.selection.primary) end),

    key({"Control"}, "w", "Delete previous word.",
        function (w) w:del_word() end),

    key({"Control"}, "u", "Delete until beginning of current line.",
        function (w) w:del_line() end),

    key({"Control"}, "h", "Delete character to the left.",
        function (w) w:del_backward_char() end),

    key({"Control"}, "d", "Delete character to the right.",
        function (w) w:del_forward_char() end),

    key({"Control"}, "a", "Move cursor to beginning of current line.",
        function (w) w:beg_line() end),

    key({"Control"}, "e", "Move cursor to end of current line.",
        function (w) w:end_line() end),

    key({"Control"}, "f", "Move cursor forward one character.",
        function (w) w:forward_char() end),

    key({"Control"}, "b", "Move cursor backward one character.",
        function (w) w:backward_char() end),

    key({"Mod1"}, "f", "Move cursor forward one word.",
        function (w) w:forward_word() end),

    key({"Mod1"}, "b", "Move cursor backward one word.",
        function (w) w:backward_word() end),
}

add_binds({"command", "search"}, readline_bindings)

-- Switching tabs with Mod1+{1,2,3,...}
mod1binds = {}
for i=1,10 do
    table.insert(mod1binds,
        key({"Mod1"}, tostring(i % 10), "Jump to tab at index "..i..".",
            function (w) w.tabs:switch(i) end))
end
add_binds("normal", mod1binds)

-- Command bindings which are matched in the "command" mode from text
-- entered into the input bar.
add_cmds({
    buf("^%S+!",
        [[Detect bang syntax in `:command!` and recursively calls
        `lousy.bind.match_cmd(..)` removing the bang from the command string
        and setting `bang = true` in the bind opts table.]],
        function (w, cmd, opts)
            local cmd, args = string.match(cmd, "^(%S+)!+(.*)")
            if cmd then
                opts = join(opts, { bang = true })
                return lousy.bind.match_cmd(w, opts.binds, cmd .. args, opts)
            end
        end),

    cmd("c[lose]", "Close current tab.",
        function (w) w:close_tab() end),

    cmd("print", "Print current page.",
        function (w) w.view:eval_js("print()") end),

    cmd("stop", "Stop loading.",
        function (w) w.view:stop() end),

    cmd("reload", "Reload page",
        function (w) w:reload() end),

    cmd("restart", "Restart browser (reload config files).",
        function (w) w:restart() end),

    cmd("write", "Save current session.",
        function (w) w:save_session() end),

    cmd("noh[lsearch]", "Clear search highlighting.",
        function (w) w:clear_search() end),

    cmd("back", "Go back in the browser history `[count=1]` items.",
        function (w, a) w:back(tonumber(a) or 1) end),

    cmd("f[orward]", "Go forward in the browser history `[count=1]` items.",
        function (w, a) w:forward(tonumber(a) or 1) end),

    cmd("inc[rease]", "Increment last number in URL.",
        function (w, a) w:navigate(w:inc_uri(tonumber(a) or 1)) end),

    cmd("o[pen]", "Open one or more URLs.",
        function (w, a) w:navigate(w:search_open(a)) end),

    cmd("t[abopen]", "Open one or more URLs in a new tab.",
        function (w, a) w:new_tab(w:search_open(a)) end),

    cmd("w[inopen]", "Open one or more URLs in a new window.",
        function (w, a) window.new{w:search_open(a)} end),

    cmd({"javascript", "js"}, "Evaluate JavaScript snippet.",
        function (w, a) w.view:eval_js(a) end),

    -- Tab manipulation commands
    cmd("tab", "Execute command and open result in new tab.",
        function (w, a) w:new_tab() w:run_cmd(":" .. a) end),

    cmd("tabd[o]", "Execute command in each tab.",
        function (w, a) w:each_tab(function (v) w:run_cmd(":" .. a) end) end),

    cmd("tabdu[plicate]", "Duplicate current tab.",
        function (w) w:new_tab(w.view.history) end),

    cmd("tabfir[st]", "Switch to first tab.",
        function (w) w:goto_tab(1) end),

    cmd("tabl[ast]", "Switch to last tab.",
        function (w) w:goto_tab(-1) end),

    cmd("tabn[ext]", "Switch to the next tab.",
        function (w) w:next_tab() end),

    cmd("tabp[revious]", "Switch to the previous tab.",
        function (w) w:prev_tab() end),

    cmd("q[uit]", "Close the current window.",
        function (w, a, o) w:close_win(o.bang) end),

    cmd({"viewsource", "vs"}, "View the source code of the current document.",
        function (w, a, o) w:toggle_source(not o.bang and true or nil) end),

    cmd({"wqall", "wq"}, "Save the session and quit.",
        function (w, a, o) w:save_session() w:close_win(o.bang) end),

    cmd("lua", "Evaluate Lua snippet.", function (w, a)
        if a then
            local ret = assert(
                loadstring("return function(w) return "..a.." end"))()(w)
            if ret then print(ret) end
        else
            w:set_mode("lua")
        end
    end),

    cmd("dump", "Dump current tabs html to file.",
        function (w, a)
            local fname = string.gsub(w.win.title, '[^%w%.%-]', '_')..'.html' -- sanitize filename
            local file = a or luakit.save_file("Save file", w.win, xdg.download_dir or '.', fname)
            if file then
                local fd = assert(io.open(file, "w"), "failed to open: " .. file)
                local html = assert(w.view:eval_js("document.documentElement.outerHTML"), "Unable to get HTML")
                assert(fd:write(html), "unable to save html")
                io.close(fd)
                w:notify("Dumped HTML to: " .. file)
            end
        end),
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
