--- Default bind configuration for luakit.
--
-- This module defines the default set of keybindings that luakit uses, in
-- various modes.
--
-- @module binds
-- @author Aidan Holm <aidanholm@gmail.com>
-- @author Mason Larobina (mason-l) <mason.larobina@gmail.com>
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com>

local _M = {}

local window = require("window")
local globals = require("globals")

-- Binding aliases
local lousy = require("lousy")
local modes = require("modes")

-- Util aliases
local join, split = lousy.util.table.join, lousy.util.string.split

-- Globals or defaults that are used in binds
local scroll_step = globals.scroll_step or 20
local page_step = globals.page_step or 1.0
local zoom_step = globals.zoom_step or 0.1

--- Compatibility wrapper for @ref{modes/add_binds|modes.add_binds()}.
-- @deprecated use @ref{modes/add_binds|modes.add_binds()} instead.
_M.add_binds = function (...)
    msg.warn("binds.add_binds() is deprecated and will be removed in a future version!")
    msg.warn("please use modes.add_binds() instead")
    return modes.add_binds(...)
end

--- Compatibility wrapper for @ref{modes/add_cmds|modes.add_cmds()}.
-- @deprecated use @ref{modes/add_cmds|modes.add_cmds()} instead.
_M.add_cmds = function (...)
    msg.warn("binds.add_cmds() is deprecated and will be removed in a future version!")
    msg.warn("please use modes.add_cmds() instead")
    return modes.add_cmds(...)
end

--- Table of bindings for the luakit menu.
-- @readwrite
-- @type table
_M.menu_binds = {
    -- Navigate items
    { "j",           "Move the menu row focus downwards.", function (w) w.menu:move_down() end },
    { "k",           "Move the menu row focus upwards.",   function (w) w.menu:move_up()   end },
    { "<Down>",      "Move the menu row focus downwards.", function (w) w.menu:move_down() end },
    { "<Up>",        "Move the menu row focus upwards.",   function (w) w.menu:move_up()   end },
    { "<KP_Down>",   "Move the menu row focus downwards.", function (w) w.menu:move_down() end },
    { "<KP_Up>",     "Move the menu row focus upwards.",   function (w) w.menu:move_up()   end },
    { "<Tab>",       "Move the menu row focus downwards.", function (w) w.menu:move_down() end },
    { "<Shift-Tab>", "Move the menu row focus upwards.",   function (w) w.menu:move_up()   end },
}

-- Add binds to special mode "all" which adds its binds to all modes.
modes.add_binds("all", {
    { "<Escape>", "Return to `normal` mode.", function (w) w:set_prompt(); w:set_mode() end },
    { "<Control-[>", "Return to `normal` mode.", function (w) w:set_mode() end },
    { "<Mouse2>", [[Open link under mouse cursor in new tab or navigate to the
        contents of `luakit.selection.primary`.]],
        function (w, m)
            -- Ignore button 2 clicks in form fields
            if not m.context.editable then
                -- Open hovered uri in new tab
                local uri = w.view.hovered_uri
                if uri then
                    w:new_tab(uri, { switch = false })
                else -- Open selection in current tab
                    uri = luakit.selection.primary
                    -- Ignore multi-line selection contents
                    if uri and not string.match(uri, "\n.+") then
                        w:navigate(w:search_open(uri))
                    end
                end
            end
        end
    },

    { "<Control-Mouse1>", "Open link under mouse cursor in new tab.",
        function (w)
            local uri = w.view.hovered_uri
            if uri then
                w:new_tab(uri, { switch = false, private = w.view.private })
            end
        end },

    { "<Control-Mouse4>", "Increase text zoom level.", function (w) w:zoom_in() end },
    { "<Control-Mouse5>", "Reduce text zoom level.", function (w) w:zoom_out() end },
    { "<Shift-Mouse4>", "Scroll left.", function (w) w:scroll{ xrel = -scroll_step } end },
    { "<Shift-Mouse5>", "Scroll right.", function (w) w:scroll{ xrel = scroll_step } end },
})

local actions = { scroll = {
    up = {
        desc = "Scroll the current page up.",
        func = function (w, m) w:scroll{ yrel = -scroll_step*(m.count or 1) } end,
    },
    down = {
        desc = "Scroll the current page down.",
        func = function (w, m) w:scroll{ yrel =  scroll_step*(m.count or 1) } end,
    },
    left = {
        desc = "Scroll the current page left.",
        func = function (w, m) w:scroll{ xrel = -scroll_step*(m.count or 1) } end,
    },
    right = {
        desc = "Scroll the current page right.",
        func = function (w, m) w:scroll{ xrel =  scroll_step*(m.count or 1) } end,
    },
    page_up = {
        desc = "Scroll the current page up a full screen.",
        func = function (w, m) w:scroll{ ypagerel = -page_step*(m.count or 1) } end,
    },
    page_down = {
        desc = "Scroll the current page down a full screen.",
        func = function (w, m) w:scroll{ ypagerel =  page_step*(m.count or 1) } end,
    },
}}

modes.add_binds("normal", {
    -- Autoparse the `[count]` before a binding and re-call the hit function
    -- with the count removed and added to the opts table.
    { "<any>", [[Meta-binding to detect the `^[count]` syntax. The `[count]` is parsed
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
            local count, buffer
            if m.buffer then
                count = string.match(m.buffer, "^(%d+)")
            end
            if count then
                buffer = string.sub(m.buffer, #count + 1, (m.updated_buf and -2) or -1)
                local opts = join(m, {count = tonumber(count)})
                opts.buffer = (#buffer > 0 and buffer) or nil
                if lousy.bind.hit(w, m.binds, m.mods, m.key, opts) then
                    return true
                end
            end
            return false
        end },

    { "i", "Enter `insert` mode.", function (w) w:set_mode("insert") end, {} },
    { ":", "Enter `command` mode.", function (w) w:set_mode("command") end, {} },

    -- Scrolling
    { "j", actions.scroll.down },
    { "k", actions.scroll.up },
    { "h", actions.scroll.left },
    { "l", actions.scroll.right },
    { "<Down>",  actions.scroll.down },
    { "<Up>",    actions.scroll.up },
    { "<Left>",  actions.scroll.left },
    { "<Right>", actions.scroll.right },
    { "<KP_Down>",  actions.scroll.down },
    { "<KP_Up>",    actions.scroll.up },
    { "<KP_Left>",  actions.scroll.left },
    { "<KP_Right>", actions.scroll.right },

    { "^", "Scroll to the absolute left of the document.", function (w) w:scroll{ x =  0 } end },
    { "$", "Scroll to the absolute right of the document.", function (w) w:scroll{ x = -1 } end },
    { "0", "Scroll to the top of the document.",
        function (w, m)
            if not m.count then w:scroll{ y = 0 } else return false end
        end },
    { "<Control-e>", actions.scroll.down },
    { "<Control-y>", actions.scroll.up },

    { "<Control-d>", "Scroll half page down.", function (w) w:scroll{ ypagerel =  0.5 } end },
    { "<Control-u>", "Scroll half page up.", function (w) w:scroll{ ypagerel = -0.5 } end },
    { "<Control-f>", actions.scroll.page_down },
    { "<Control-b>", actions.scroll.page_up },
    { "<space>", actions.scroll.page_down },
    { "<Shift-space>", actions.scroll.page_up },
    { "<BackSpace>", actions.scroll.page_up },
    { "<Page_Down>", actions.scroll.page_down },
    { "<Page_Up>", actions.scroll.page_up },
    { "<KP_Next>", actions.scroll.page_down },
    { "<KP_Page_Up>", actions.scroll.page_up },
    { "<Home>", "Scroll to the top of the document.", function (w) w:scroll{ y =  0 } end },
    { "<End>", "Scroll to the end of the document.", function (w) w:scroll{ y = -1 } end },
    { "<KP_Home>", "Scroll to the top of the document.", function (w) w:scroll{ y =  0 } end },
    { "<KP_End>", "Scroll to the end of the document.", function (w) w:scroll{ y = -1 } end },

    -- Specific scroll
    { "gg", "Go to the top of the document.", function (w, m) w:scroll{ ypct = m.count } end, {count=0} },
    { "G", "Go to the bottom of the document.", function (w, m) w:scroll{ ypct = m.count } end, {count=100} },
    { "%", "Go to `[count]` percent of the document.", function (w, m) w:scroll{ ypct = m.count } end },

    -- Zoom
    { "+", "Enlarge text zoom of the current page.", function (w, m) w:zoom_in(zoom_step * m.count) end, {count=1} },
    { "-", "Reduce text zom of the current page.", function (w, m) w:zoom_out(zoom_step * m.count) end, {count=1} },
    { "=", "Reset zoom level.", function (w, _) w:zoom_set() end },
    { "zi", "Enlarge text zoom of current page.", function (w, m) w:zoom_in(zoom_step  * m.count) end, {count=1} },
    { "zo", "Reduce text zoom of current page.", function (w, _, m) w:zoom_out(zoom_step * m.count) end, {count=1} },
    { "zz", [[Set current page zoom to `[count]` percent with `[count]zz`, use `[count]zZ` to set full zoom percent.]],
        function (w, _, m) w:zoom_set(m.count/100) end, {count=100} },
    { "<F11>", "Toggle fullscreen mode.", function (w) w.win.fullscreen = not w.win.fullscreen end },

    -- Open primary selection contents.
    { "pp", [[Open URLs based on the current primary selection contents in the current tab.]],
        function (w)
            local uris = {}
            for uri in string.gmatch(luakit.selection.primary or "", "%S+") do
                table.insert(uris, uri)
            end
            if #uris == 0 then w:notify("Nothing in primary selection...") return end
            w:navigate(w:search_open(uris[1]))
            if #uris > 1 then
                for i=2,#uris do
                    w:new_tab(w:search_open(uris[i]))
                end
            end
        end },
    { "pt", [[Open a URL based on the current primary selection contents in `[count=1]` new tab(s).]],
            function (w, _, m)
                local uri = luakit.selection.primary
                if not uri then w:notify("No primary selection...") return end
                for _ = 1, m.count do w:new_tab(w:search_open(uri)) end
        end, {count = 1} },
    { "^pw$", [[Open URLs based on the current primary selection contents in a new window.]],
        function(w)
            local uris = {}
            for uri in string.gmatch(luakit.selection.primary or "", "%S+") do
                table.insert(uris, uri)
            end
            if #uris == 0 then w:notify("Nothing in primary selection...") return end
            w = window.new{w:search_open(uris[1])}
            if #uris > 1 then
                for i=2,#uris do
                    w:new_tab(w:search_open(uris[i]))
                end
            end
        end },

    -- Open clipboard contents.
    { "^PP$", [[Open URLs based on the current clipboard selection contents in the current tab.]],
        function (w)
            local uris = {}
            for uri in string.gmatch(luakit.selection.clipboard or "", "%S+") do
                table.insert(uris, uri)
            end
            if #uris == 0 then w:notify("Nothing in clipboard...") return end
            w:navigate(w:search_open(uris[1]))
            if #uris > 1 then
                for _=2,#uris do
                    w:new_tab(w:search_open(uris[1]))
                end
            end
        end },

    { "^PT$", [[Open a URL based on the current clipboard selection contents in `[count=1]` new tab(s).]],
        function (w, _, m)
            local uri = luakit.selection.clipboard
            if not uri then w:notify("Nothing in clipboard...") return end
            for _ = 1, m.count do w:new_tab(w:search_open(uri)) end
    end, {count = 1} },

    { "^PW$", [[Open URLs based on the current clipboard selection contents in a new window.]],
        function(w)
            local uris = {}
            for uri in string.gmatch(luakit.selection.clipboard or "", "%S+") do
                table.insert(uris, uri)
            end
            if #uris == 0 then w:notify("Nothing in clipboard...") return end
            w = window.new{w:search_open(uris[1])}
            if #uris > 1 then
                for i=2,#uris do
                    w:new_tab(w:search_open(uris[i]))
                end
            end
        end },

    -- Yanking
    { "y", "Yank current URI to primary selection.", function (w)
            local uri = string.gsub(w.view.uri or "", " ", "%%20")
            luakit.selection.primary = uri
            w:notify("Yanked uri: " .. uri)
        end },
    {"Y", "Yank current URI to clipboard.", function (w)
        local uri = string.gsub(w.view.uri or "", " ", "%%20")
        luakit.selection.clipboard = uri
        w:notify("Yanked uri (to clipboard): " .. uri)
    end },

    -- Commands
    { "<Control-a>", "Increment last number in URL.",
        function (w, m) w:navigate(w:inc_uri(m.count)) end, {count = 1} },
    { "<Control-x>", "Decrement last number in URL.",
        function (w, m) w:navigate(w:inc_uri(-m.count)) end, {count = 1} },
    { "o", "Open one or more URLs.", function (w) w:enter_cmd(":open ") end },
    { "t", "Open one or more URLs in a new tab.", function (w) w:enter_cmd(":tabopen ") end },
    { "w", "Open one or more URLs in a new window.", function (w) w:enter_cmd(":winopen ") end },
    { "O", "Open one or more URLs based on current location.",
        function (w) w:enter_cmd(":open " .. (w.view.uri or "")) end },
    { "T", "Open one or more URLs based on current location in a new tab.",
        function (w) w:enter_cmd(":tabopen " .. (w.view.uri or "")) end },
    { "W", "Open one or more URLs based on current location in a new window.",
        function (w) w:enter_cmd(":winopen " .. (w.view.uri or "")) end },

    { "H", "Go back in the browser history `[count=1]` items.", function (w, m) w:back(m.count) end },
    { "L", "Go forward in the browser history `[count=1]` times.", function (w, m) w:forward(m.count) end },
    { "<XF86Back>", "Go back in the browser history.", function (w, m) w:back(m.count) end },
    { "<XF86Forward>", "Go forward in the browser history.", function (w, m) w:forward(m.count) end },

    { "<Control-o>", "Go back in the browser history.", function (w, m) w:back(m.count) end },
    { "<Control-i>", "Go forward in the browser history.", function (w, m) w:forward(m.count) end },

    -- Tab
    { "<Control-Page_Up>", "Go to previous tab.", function (w) w:prev_tab() end },
    { "<Control-Page_Down>", "Go to next tab.", function (w) w:next_tab() end },
    { "<Control-Tab>", "Go to next tab.", function (w) w:next_tab() end },
    { "<Shift-Control-Tab>", "Go to previous tab.", function (w) w:prev_tab() end },
    { "<F1>", "Show help.", function (w) w:run_cmd(":help") end },
    { "<F12>", "Toggle web inspector.", function (w) w:run_cmd(":inspect!") end },
    { "gT", "Go to previous tab.", function (w) w:prev_tab() end },

    { "gt", "Go to next tab (or `[count]` nth tab).",
        function (w, _, m)
            if not w:goto_tab(m.count) then w:next_tab() end
    end, {count=0} },
    { "g0", "Go to first tab.", function (w) w:goto_tab(1) end },
    { "g$", "Go to last tab.", function (w) w:goto_tab(-1) end },

    { "<Control-t>", "Open a new tab.", function (w) w:new_tab("luakit://newtab/") end },
    { "<Control-w>", "Close current tab.", function (w) w:close_tab() end },
    { "d", "Close current tab (or `[count]` tabs).",
        function (w, m) for _=1,m.count do w:close_tab() end end, {count=1} },

    { "<", "Reorder tab left `[count=1]` positions.",
        function (w, m)
            w.tabs:reorder(w.view,
                (w.tabs:current() - m.count) % w.tabs:count())
        end, {count=1} },

    { ">", "Reorder tab right `[count=1]` positions.",
        function (w, m)
            w.tabs:reorder(w.view,
                (w.tabs:current() + m.count) % w.tabs:count())
        end, {count=1} },

    { "^gH$", "Open homepage in new tab.", function (w) w:new_tab(globals.homepage) end },
    { "^gh$", "Open homepage.", function (w) w:navigate(globals.homepage) end },
    { "^gy$", "Duplicate current tab.",
        function (w)
            w:new_tab({ session_state = w.view.session_state }, { private = w.view.private })
        end },

    { "r", "Reload current tab.", function (w) w:reload() end },
    { "R", "Reload current tab (skipping cache).", function (w) w:reload(true) end },
    { "<Control-c>", "Stop loading the current tab.", function (w) w.view:stop() end },
    { "<Control-R>", "Restart luakit (reloading configs).", function (w) w:restart() end },

    -- Window
    { "^ZZ$", "Quit and save the session.", function (w) w:save_session() w:close_win() end },
    { "^ZQ$", "Quit and don't save the session.", function (w) w:close_win() end },
    { "^D$",  "Quit and don't save the session.", function (w) w:close_win() end },

    -- Enter passthrough mode
    { "<Control-z>", "Enter `passthrough` mode, ignores all luakit keybindings.",
        function (w) w:set_mode("passthrough") end },
})

modes.add_binds("insert", {
    { "<Control-z>", "Enter `passthrough` mode, ignores all luakit keybindings.",
        function (w) w:set_mode("passthrough") end },
})

--- Readline bindings for the luakit input bar.
-- @readwrite
-- @type table
_M.readline_bindings = {
    { "<Shift-Insert>", "Insert contents of primary selection at cursor position.",
        function (w) w:insert_cmd(luakit.selection.primary) end },
    { "<Control-w>", "Delete previous word.", function (w) w:del_word() end },
    { "<Control-u>", "Delete until beginning of current line.", function (w) w:del_line() end },
    { "<Control-h>", "Delete character to the left.", function (w) w:del_backward_char() end },
    { "<Control-d>", "Delete character to the right.", function (w) w:del_forward_char() end },
    { "<Control-a>", "Move cursor to beginning of current line.", function (w) w:beg_line() end },
    { "<Control-e>", "Move cursor to end of current line.", function (w) w:end_line() end },
    { "<Control-f>", "Move cursor forward one character.", function (w) w:forward_char() end },
    { "<Control-b>", "Move cursor backward one character.", function (w) w:backward_char() end },
    { "<Mod1-f>", "Move cursor forward one word.", function (w) w:forward_word() end },
    { "<Mod1-b>", "Move cursor backward one word.", function (w) w:backward_word() end },
}

modes.add_binds("command", _M.readline_bindings)

-- Switching tabs with Mod1+{1,2,3,...}
do
    local mod1binds = {}
    for i=1,10 do
        table.insert(mod1binds, {
            ("<Mod1-%d>"):format(i % 10), "Jump to tab at index "..i..".", function (w) w.tabs:switch(i) end
        })
    end
    modes.add_binds("normal", mod1binds)
end

-- Command bindings which are matched in the "command" mode from text
-- entered into the input bar.
modes.add_cmds({
    { "^%S+!", [[Detect bang syntax in `:command!` and recursively calls
        `lousy.bind.match_cmd(..)` removing the bang from the command string
        and setting `bang = true` in the bind opts table.]],
        function (w, opts)
            local command, args = opts.buffer
            command, args = string.match(command, "^(%S+)!+(.*)")
            if command then
                opts = join(opts, { bang = true })
                return lousy.bind.match_cmd(w, opts.binds, command .. args, opts)
            end
        end },

    { "<Control-Return>", [[Expand `:[tab,win]open example` to `:[tab,win]open www.example.com`.]],
        function (w)
            local tokens = split(w.ibar.input.text, "%s+")
            if string.match(tokens[1], "^:%w*open$") and #tokens == 2 then
                w:enter_cmd(string.format("%s www.%s.com", tokens[1], tokens[2]))
            end
            w:activate()
        end },

    { ":c[lose]", "Close current tab.", function (w) w:close_tab() end },
    { ":print", "Print current page.", function (w) w.view:eval_js("print()", { no_return = true }) end },
    { ":stop", "Stop loading.", function (w) w.view:stop() end },
    { ":reload", "Reload page.", function (w) w:reload() end },
    { ":restart", "Restart browser (reload config files).", function (w, o) w:restart(o.bang) end },
    { ":write", "Save current session.", function (w) w:save_session() end },
    { ":noh[lsearch]", "Clear search highlighting.", function (w) w:clear_search() end },
    { ":back", "Go back in the browser history `[count=1]` items.", function (w, o) w:back(tonumber(o.arg) or 1) end },
    { ":f[orward]", "Go forward in the browser history `[count=1]` items.",
        function (w, o) w:forward(tonumber(o.arg) or 1) end },
    { ":inc[rease]", "Increment last number in URL.", function (w, o) w:navigate(w:inc_uri(tonumber(o.arg) or 1)) end },
    { ":o[pen]", "Open one or more URLs.", {
        func = function (w, o) w:navigate(w:search_open(o.arg)) end,
        format = "{uri}",
    }},
    { ":t[abopen]", "Open one or more URLs in a new tab.", {
        func = function (w, o) w:new_tab(w:search_open(o.arg)) end,
        format = "{uri}",
    }},
    { ":priv-t[abopen]", "Open one or more URLs in a new private tab.", {
        func = function (w, o) w:new_tab(w:search_open(o.arg), { private = true }) end,
        format = "{uri}",
    }},
    { ":w[inopen]", "Open one or more URLs in a new window.", {
        func = function (w, o) window.new{w:search_open(o.arg)} end,
        format = "{uri}",
    }},
    { ":javascript, :js", "Evaluate JavaScript snippet.",
        function (w, o) w.view:eval_js(o.arg, {
                    no_return = true,
                    callback = function (_, err)
                        w:error(err)
                    end,
                }) end },

    -- Tab manipulation commands
    { ":tab", "Execute command and open result in new tab.", {
        func = function (w, o) w:new_tab() w:run_cmd(":" .. o.arg) end,
        format = "{command}",
    }},
    { ":tabd[o]", "Execute command in each tab.", {
        func = function (w, o) w:each_tab(function () w:run_cmd(":" .. o.arg) end) end,
        format = "{command}",
    }},
    { ":tabdu[plicate]", "Duplicate current tab.",
        function (w) w:new_tab({ session_state = w.view.session_state }) end },
    { ":tabfir[st]", "Switch to first tab.", function (w) w:goto_tab(1) end },
    { ":tabl[ast]", "Switch to last tab.", function (w) w:goto_tab(-1) end },
    { ":tabn[ext]", "Switch to the next tab.", function (w) w:next_tab() end },
    { ":tabp[revious]", "Switch to the previous tab.", function (w) w:prev_tab() end },
    { ":tabde[tach]", "Move the current tab tab into a new window.", function (w) window.new({w.view}) end },
    { ":q[uit]", "Close the current window.", function (w, o) w:close_win(o.bang) end },

    { ":wq[all]", "Save the session and quit.", function (w, o)
        local force = o.bang
        if not force and not w:can_quit() then return end
        w:save_session()
        for _, ww in pairs(window.bywidget) do
            ww:close_win(true)
        end
    end },

    { ":lua", "Evaluate Lua snippet.", function (w, o)
            local a = o.arg
            if a then
                -- Parse as expression first, then statement
                -- With this order an error message won't contain the print() wrapper
                local ret, err = loadstring("print(" .. a .. ")", "lua-cmd")
                if err then
                    ret, err = loadstring(a, "lua-cmd")
                end
                if err then
                    w:error(err)
                else
                    setfenv(ret, setmetatable({}, { __index = function (_, k)
                        if _G[k] ~= nil then return _G[k] end
                        if k == "w" then return w end
            end, __newindex = _G }))
        ret()
    end
else
    w:set_mode("lua")
end
    end },

    { ":dump", "Dump current tabs html to file.",
        function (w, o)
            local fname = string.gsub(w.win.title, '[^%w%.%-]', '_')..'.html' -- sanitize filename
            local file = o.arg or luakit.save_file("Save file", w.win, xdg.download_dir or '.', fname)
            if file then
                local fd = assert(io.open(file, "w"), "failed to open: " .. file)
                local html = assert(w.view.source, "Unable to get HTML")
                assert(fd:write(html), "unable to save html")
                io.close(fd)
                w:notify("Dumped HTML to: " .. file)
            end
        end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
