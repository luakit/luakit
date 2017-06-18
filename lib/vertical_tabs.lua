--- UI mod: vertical tabs.
--
-- This module moves the tab bar to the side.
--
-- @module vertical_tabs
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local _M = {}

local window = require("window")
local lousy = require("lousy")
local globals = require("globals")

window.add_signal("build", function (w)
    -- Replace the existing tablist with a vertical one
    w.tablist:destroy()
    w.tablist = lousy.widget.tablist(w.tabs, "vertical")

    -- Add a paned widget: tablist on left, repack w.tabs on right
    local paned = widget{type="hpaned"}
    paned:pack1(w.tablist.widget, { resize = false, shrink = true })
    w.tabs.parent.child = nil
    paned:pack2(w.tabs)
    paned.position = globals.vertical_tab_width or 200

    w.menu_tabs.child = paned
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
