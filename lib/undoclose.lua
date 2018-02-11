--- View and reopen closed tabs in an interactive menu.
--
-- This module provides support for reopening previously-closed tabs.
-- The set of closed tabs is saved in the luakit session, so users can
-- still reopen tabs after a restart.
--
-- This module also provides a menu that allows viewing the full set of closed
-- tabs, as well as opening them directly.
--
-- @module undoclose
-- @copyright 2010 Chris van Dijk <quigybo@hotmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local window = require("window")
local lousy = require("lousy")
local binds, modes = require("binds"), require("modes")
local add_binds, add_cmds = modes.add_binds, modes.add_cmds
local menu_binds = binds.menu_binds
local new_mode = require("modes").new_mode
local session = require("session")

local _M = {}

lousy.signal.setup(_M, true)

local reopening = {}

-- Map of view widgets to UIDs that are restored after reopening a web view
local view_uids = setmetatable({}, { __mode = "k" })

-- Map of notebook widgets to closed tab lists
local closed_tabs = setmetatable({}, { __mode = "k" })

--- Returns a webview widget's UID, creating one if necessary.
-- @tparam widget view The webview.
-- @treturn number The UID for the webview.
local uid_from_view = function (view)
    assert(type(view) == "widget" and view.type == "webview")
    local uid = view_uids[view]
    if not uid then
        uid = view_uids.next or 0
        view_uids.next = uid + 1
        view_uids[view] = uid
    end
    return uid
end

--- Returns a webview with the given UID, if one exists.
-- @tparam number uid The UID.
-- @treturn widget The webview widget.
local view_from_uid = function (uid)
    if not uid then return end
    assert(type(uid) == "number" and uid >= 0)
    for v, u in pairs(view_uids) do
        if u == uid and type(v) == "widget" then return v end
    end
end

local on_tab_close = function (w, view)
    local tab
    -- Save tab history
    if reopening[view] then
        -- If we're still reopening the tab we're closing, then we haven't yet
        -- initialized it; reuse the restoration data for this tab
        tab = reopening[view]
        reopening[view] = nil
    else
        local index = w.tabs:indexof(view)
        local hist = view.history
        local hist_item = hist.items[hist.index]
        local title = lousy.util.escape(hist_item.title) or ""

        -- Don't save the "New Tab" page in undoclose history
        if _M.emit_signal("save", view) == false then
            return
        end

        tab = {
            session_state = view.session_state,
            uri = view.uri,
            title = title,
            self_uid = uid_from_view(view),
            after_uid = (index ~= 1) and uid_from_view(w.tabs[index-1]),
        }
        view_uids[view] = nil
        if view.uri ~= hist_item.uri then tab.next_uri = view.uri end
    end
    closed_tabs[w.tabs] = closed_tabs[w.tabs] or {}
    table.insert(closed_tabs[w.tabs], tab)
end

-- Undo a closed tab (with complete tab history)
window.methods.undo_close_tab = function (w, index)
    local ctabs = closed_tabs[w.tabs] or {}
    -- Convert negative indexes
    if index and index < 0 then
        index = #ctabs + index + 1
    end
    local tab = table.remove(ctabs, index)
    if not tab then
        w:notify("No closed tabs to reopen")
        return
    end
    -- Restore the view
    local view = w:new_tab({session_state = tab.session_state})
    -- If tab was in the middle of a page load when it was closed, continue that now
    if tab.next_uri then
        view.uri = tab.next_uri
    end

    reopening[view] = tab
    -- Restore saved view uid
    view_uids[view] = tab.self_uid
    -- Attempt to open in last position
    local after = view_from_uid(tab.after_uid)
    if after then
        local i = w.tabs:indexof(after)
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

session.add_signal("save", function (state)
    for _, w in pairs(window.bywidget) do
        -- Save closed tabs for each window
        assert(state[w])
        assert(not state[w].closed)
        state[w].closed = {}
        for i, tab in ipairs(closed_tabs[w.tabs] or {}) do
            state[w].closed[i] = tab
        end
        -- Save view uids for each view
        -- HACK: This is rather brittle; need a better API for session stuff
        for i, v in ipairs(w.tabs.children) do
            if not v.private then
                state[w].open[i].view_uid = view_uids[v]
            end
        end
    end
end)

session.add_signal("restore", function (state)
    view_uids.next = 0
    for w, win in pairs(state) do
        -- Restore closed tabs for each window
        closed_tabs[w.tabs] = win.closed
        -- Save view uids for each view, reconstruct view_uids.next
        for i, v in ipairs(w.tabs.children) do
            local uid = win.open[i].view_uid
            view_uids[v] = uid
            if uid and uid >= view_uids.next then
                view_uids.next = uid + 1
            end
        end
    end
end)

window.add_signal("init", function (w)
    w:add_signal("close-tab", on_tab_close)
end)

add_binds("normal", {
    { "u", "Undo closed tab (restoring tab history).",
        function (w, m) w:undo_close_tab(-m.count) end, {count=1} },
})

-- View closed tabs in a list
new_mode("undolist", {
    enter = function (w)
        local rows = {{ "Title", " URI", title = true }}
        for uid, tab in ipairs(closed_tabs[w.tabs] or {}) do
            tab.uid = uid
            local title = lousy.util.escape(tab.title)
            local uri = lousy.util.escape(tab.uri)
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
    { "d", "Delete closed tab history item.", function (w)
        local row = w.menu:get()
        local ctabs = closed_tabs[w.tabs] or {}
        if row and row.uid then
            for i, tab in ipairs(ctabs) do
                if tab.uid == row.uid then
                    table.remove(ctabs, i)
                    break
                end
            end
            w.menu:del()
            if w.menu:nrows() == 1 then
                w:notify("No closed tabs to display")
            end
        end
    end },

    { "u", "Undo closed tab in new background tab.", function (w)
        local row = w.menu:get()
        local ctabs = closed_tabs[w.tabs] or {}
        if row and row.uid then
            for i, tab in ipairs(ctabs) do
                if tab.uid == row.uid then
                    w:new_tab(table.remove(ctabs, i), { switch = false })
                    break
                end
            end
            w.menu:del()
            if w.menu:nrows() == 1 then
                w:notify("No closed tabs to display")
            end
        end
    end },

    -- Undo closed tab in new window
    { "w", "Undo closed tab in new window.", function (w)
        local row = w.menu:get()
        local ctabs = closed_tabs[w.tabs] or {}
        w:set_mode()
        if row and row.uid then
            for i, tab in ipairs(ctabs) do
                if tab.uid == row.uid then
                    window.new({table.remove(ctabs, i)})
                    return
                end
            end
        end
    end },

    -- Undo closed tab in current tab
    { "<Return>", "Undo closed tab in current tab.", function (w)
        local row = w.menu:get()
        w:set_mode()
        if row and row.uid then
            for i, tab in ipairs(closed_tabs[w.tabs] or {}) do
                if tab.uid == row.uid then
                    w:undo_close_tab(i)
                end
            end
        end
    end },
}, menu_binds))

-- Add `:undolist` command to view all closed tabs in an interactive menu
add_cmds({
    { ":undolist", "Undo closed tabs menu.",
        function (w)
            if #(closed_tabs[w.tabs] or {}) == 0 then
                w:notify("No closed tabs to display")
            else
                w:set_mode("undolist")
            end
        end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
