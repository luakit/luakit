------------------------------------------------------
-- View and undo closed tabs in an interactive menu --
-- © 2010 Chris van Dijk <quigybo@hotmail.com>      --
-- © 2010 Mason Larobina <mason.larobina@gmail.com> --
------------------------------------------------------

local window = require("window")

local reopening = {}

local on_tab_close = function (w, view)
    local tab
    -- Save tab history
    if reopening[view] then
        -- If we're still reopening the tab we're closing, then we haven't yet
        -- initialized it; reuse the restoration data for this tab
        tab = reopening[view]
        reopening[view] = nil
    else
        tab = { hist = view.history, session_state = view.session_state }
    end
    -- And relative location
    local index = w.tabs:indexof(view)
    if index ~= 1 then tab.after = w.tabs[index-1] end
    table.insert(w.closed_tabs, tab)
end

-- Undo a closed tab (with complete tab history)
window.methods.undo_close_tab = function (w, index)
    -- Convert negative indexes
    if index and index < 0 then
        index = #(w.closed_tabs) + index + 1
    end
    local tab = table.remove(w.closed_tabs, index)
    if not tab then
        w:notify("No closed tabs to reopen")
        return
    end
    local view = w:new_tab({ session_state = tab.session_state, hist = tab.hist })
    reopening[view] = tab
    -- Attempt to open in last position
    if tab.after then
        local i = w.tabs:indexof(tab.after)
        w.tabs:reorder(view, (i and i+1) or -1)
    else
        w.tabs:reorder(view, 1)
    end

    -- Emit 'undo-close' after webview init funcs have run
    view:add_signal("web-extension-loaded", function(v)
        v:emit_signal("undo-close")
        reopening[view] = nil
    end)
end

window.init_funcs.undo_close_tab = function (w)
    w.closed_tabs = {}
    w:add_signal("close-tab", on_tab_close)
end

local key = lousy.bind.key
add_binds("normal", {
    key({}, "u", "Undo closed tab (restoring tab history).",
        function (w, m) w:undo_close_tab(-m.count) end, {count=1}),
})

-- View closed tabs in a list
local escape = lousy.util.escape
new_mode("undolist", {
    enter = function (w)
        local rows = {{ "Title", " URI", title = true }}
        for uid, tab in ipairs(w.closed_tabs) do
            tab.uid = uid
            local item = tab.hist.items[tab.hist.index]
            local title, uri = escape(item.title) or "", escape(item.uri)
            table.insert(rows, 2, { "  " .. title, " " .. uri, uid = uid })
        end
        w.menu:build(rows)
        w:notify("Use j/k to move, d delete, u undo, w winopen.", false)
    end,

    leave = function (w)
        w.menu:hide()
    end,
})

-- Add undolist menu binds
add_binds("undolist", lousy.util.table.join({
    -- Delete closed tab history
    key({}, "d", "Delete closed tab history item.", function (w)
        local row = w.menu:get()
        if row and row.uid then
            for i, tab in ipairs(w.closed_tabs) do
                if tab.uid == row.uid then
                    table.remove(w.closed_tabs, i)
                    break
                end
            end
            w.menu:del()
            if w.menu:nrows() == 1 then
                w:notify("No closed tabs to display")
            end
        end
    end),

    key({}, "u", "Undo closed tab in new background tab.", function (w)
        local row = w.menu:get()
        if row and row.uid then
            for i, tab in ipairs(w.closed_tabs) do
                if tab.uid == row.uid then
                    w:new_tab(table.remove(w.closed_tabs, i), false)
                    break
                end
            end
            w.menu:del()
            if w.menu:nrows() == 1 then
                w:notify("No closed tabs to display")
            end
        end
    end),

    -- Undo closed tab in new window
    key({}, "w", "Undo closed tab in new window.", function (w)
        local row = w.menu:get()
        w:set_mode()
        if row and row.uid then
            for i, tab in ipairs(w.closed_tabs) do
                if tab.uid == row.uid then
                    window.new({table.remove(w.closed_tabs, i)})
                    return
                end
            end
        end
    end),

    -- Undo closed tab in current tab
    key({}, "Return", "Undo closed tab in current tab.", function (w)
        local row = w.menu:get()
        w:set_mode()
        if row and row.uid then
            for i, tab in ipairs(w.closed_tabs) do
                if tab.uid == row.uid then
                    w:undo_close_tab(i)
                end
            end
        end
    end),

    -- Exit menu
    key({}, "q", "Close menu.",
        function (w) w:set_mode() end),

}, menu_binds))

-- Add `:undolist` command to view all closed tabs in an interactive menu
local cmd = lousy.bind.cmd
add_cmds({
    cmd("undolist", "Undo closed tabs menu.", function (w, a)
        if #(w.closed_tabs) == 0 then
            w:notify("No closed tabs to display")
        else
            w:set_mode("undolist")
        end
    end),
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
