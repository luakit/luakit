--- Switch tabs using a menu widget.
--
-- This module adds a command which lists all open tabs.
--
-- @module tabmenu
-- @author 2012 Alexander Clare <alexander.clare@gmail.com>

local ipairs = ipairs
local table = table

local lousy = require "lousy"
local modes = require "modes"
local binds = require "binds"
local add_binds = modes.add_binds
local add_cmds = modes.add_cmds
local new_mode = modes.new_mode

local _M = {}

--- Whether the tab menu is displayed or not.
-- @type boolean
-- @readwrite
-- @default `false`
_M.hide_box = false

add_cmds({
      { ":tabmenu", [[Open tab menu.]], function (w) w:set_mode("tabmenu") end },
})

local escape = lousy.util.escape

new_mode("tabmenu", {
    enter = function (w)
        _M.hide_box = not w.sbar.ebox.visible
        local rows = {}
        for _, view in ipairs(w.tabs.children) do
            if not view.uri then view.uri = " " end
            table.insert(rows, {escape(view.uri), escape(view.title), v = view })
        end
        w.menu:build(rows)
        local cur = w.tabs:current()
        local ind = 0
        repeat w.menu:move_down(); ind = ind + 1 until ind == cur
        w.sbar.ebox:show()
        w:notify("Del - close, Return - switch.", false)
    end,

    leave = function (w)
        if _M.hide_box == true then
            w.sbar.ebox:hide()
        end
        w.menu:hide()
    end,
})


add_binds("tabmenu", lousy.util.table.join({
    { "<Delete>", "Delete tab.", function (w)
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
    end },
    { "<Return>", "Open tab.", function (w)
        local row = w.menu:get()
        if row and row.v then
            local cur = w.view
            if cur ~= row.v then
                w.tabs:switch((w.tabs:indexof(row.v)))
            else
                w:set_mode()
            end
        end
    end },
}, binds.menu_binds))

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
