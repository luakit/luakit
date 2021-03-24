--- Tabgroup name - status bar widget.
--
-- Shows the name of the current tabgroup.
--
-- @module lousy.widget.tgname
-- @copyright 2021 Tao Nelson <taobert@gmail.com>
-- Derived from lousy.widget.uri
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local _M = {}

local webview = require("webview")
local lousy = require("lousy")
local theme = lousy.theme.get()
local wc = require("lousy.widget.common")
local tabgroups = require('tabgroups')

local widgets = {
    update = function (w,tgname)
        tgname.text = lousy.util.escape('['..tabgroups.current_tabgroup(w)..']')
    end,
}

webview.add_signal("init", function (view)
    -- `switch_tabgroup()` and `tabgroup-menu-rename` emit `switched-page`
    view:add_signal("switched-page", function (v)
        wc.update_widgets_on_w(widgets, webview.window(v))
    end)
end)

local function new()
    local tgname = widget{type="label"}
    tgname.selectable = true
    tgname.can_focus = false
    tgname.fg = theme.sbar_fg
    tgname.font = theme.sbar_font
    return wc.add_widget(widgets, tgname)
end

return setmetatable(_M, { __call = function(_, ...) return new(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
