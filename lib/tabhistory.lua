--- View and open history items in an interactive menu.
--
-- @module tabhistory
-- @copyright 2010 Fabian Streitel <karottenreibe@gmail.com>
-- @copyright 2010 Mason Larobina  <mason.larobina@gmail.com>

local window = require("window")
local lousy = require("lousy")
local new_mode = require("modes").new_mode
local binds = require("binds")
local add_binds, add_cmds = binds.add_binds, binds.add_cmds
local menu_binds = binds.menu_binds
local util = require("lousy.util")
local join = util.table.join

local _M = {}

-- View history items in an interactive menu.
new_mode("tabhistory", {
    leave = function (w)
        w.menu:hide()
    end,

    enter = function (w)
        local h = w.view.history
        local rows = {{"Title", "URI", title = true},}
        for i, hi in ipairs(h.items) do
            local title, uri = util.escape(hi.title) or "", util.escape(hi.uri)
            local marker = (i == h.index and "* " or "  ")
            table.insert(rows, 2, { (marker..title), uri, index=i})
        end
        w.menu:build(rows)
        w:notify("Use j/k to move, w winopen, t tabopen.", false)
    end,
})

-- Add history menu binds.
local key = lousy.bind.key
add_binds("tabhistory", join({
    -- Open history item in new tab.
    key({}, "t", "Open the currently highlighted history item in a new tab.",
        function (w)
        local row = w.menu:get()
        if row and row.index then
            local v = w.view
            local uri = v.history.items[row.index].uri
            w:new_tab(uri, false)
        end
    end),

    -- Open history item in new window.
    key({}, "w", "Open the currently highlighted history item in a new window.",
        function (w)
        local row = w.menu:get()
        w:set_mode()
        if row and row.index then
            local v = w.view
            local uri = v.history.items[row.index].uri
            window.new({uri})
        end
    end),

    -- Go to history item.
    key({}, "Return", "Open the currently highlighted history item in the current tab.",
        function (w)
        local row = w.menu:get()
        w:set_mode()
        if row and row.index then
            local v = w.view
            local offset = row.index - v.history.index
            if offset < 0 then
                v:go_back(-offset)
            elseif offset > 0 then
                v:go_forward(offset)
            end
        end
    end),

}, menu_binds))

-- Additional window methods.
window.methods.tab_history = function (w)
    if #(w.view.history.items) < 2 then
        w:notify("No history items to display")
    else
        w:set_mode("tabhistory")
    end
end

-- Add `:history` command to view all history items for the current tab in an interactive menu.
local cmd = lousy.bind.cmd
add_cmds({
    cmd("tabhistory", "List page history for the current tab.", window.methods.tab_history),
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
