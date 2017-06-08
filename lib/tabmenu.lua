----------------------------------------------------------------
-- Switch tabs using a menu widget                            --
-- © 2012 Alexander Clare <alexander.clare@gmail.com>         --
----------------------------------------------------------------

local ipairs = ipairs
local table = table

local lousy = require "lousy"
local add_binds, add_cmds = add_binds, add_cmds
local new_mode, menu_binds = new_mode, menu_binds

module("tabmenu")

local cmd = lousy.bind.cmd
add_cmds({
    cmd("tabmenu", function (w) w:set_mode("tabmenu") end),
})

local escape = lousy.util.escape
new_mode("tabmenu", {
    enter = function (w)
        local rows = {}
        for _, view in ipairs(w.tabs.children) do
            table.insert(rows, {escape(view.uri), escape(view.title), v = view })
        end
        w.menu:build(rows)
        local cur = w.tabs:current()
        local ind = 0
        repeat w.menu:move_down(); ind = ind + 1 until ind == cur
        w.sbar.ebox:show()
        w:notify("Use j/k to move, d close, Return switch.", false)
    end,

    leave = function (w)
        w.sbar.ebox:hide()
        w.menu:hide()
    end,
})

local key = lousy.bind.key
add_binds("tabmenu", lousy.util.table.join({
    -- Close tab
    key({}, "d", function (w)
        local row = w.menu:get()
        if row and row.v then
            local cur = w.view
            w:close_tab(w.tabs[w.tabs:indexof(row.v)])
            if cur ~= row.v then
                w.menu:del()
            else
                w:set_mode()
            end
        end
    end),

    -- Switch to tab
    key({}, "Return", function (w)
        local row = w.menu:get()
        if row and row.v then
            local cur = w.view
            if cur ~= row.v then
                w.tabs:switch((w.tabs:indexof(row.v)))
            else
                w:set_mode()
            end
        end
    end),

    -- Exit menu
    key({}, "`", function (w) w:set_mode() end),

}, menu_binds))
