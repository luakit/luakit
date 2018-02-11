--- Web page zoom level - status bar widget.
--
-- Shows the zoom levle of the current web page as a percentage.
--
-- @module lousy.widget.zoom
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2014 Justin Forest

local webview = require("webview")
local lousy = require("lousy")
local theme = lousy.theme.get()
local wc = require("lousy.widget.common")
local settings = require("settings")

local _M = {}

--- Format string which defines the appearance of the widget.
-- This is passed to `string.format` the the zoom level as a numerical argument.
-- @type string
-- @readwrite
_M.format = "[zoom:%d%%]"

local widgets = {
    update = function (w, zoom)
        local zl = w.view.zoom_level
        if zl == settings.get_setting("webview.zoom_level") / 100 then
            zoom:hide()
        else
            zoom:show()
            zoom.text = string.format(_M.format, zl * 100)
        end
    end,
}

webview.add_signal("init", function (view)
    -- Update widget when current page changes status
    view:add_signal("property::zoom_level", function (v)
        local w = webview.window(v)
        if w and w.view == v then
            wc.update_widgets_on_w(widgets, w)
        end
    end)
    view:add_signal("switched-page", function (v)
        wc.update_widgets_on_w(widgets, webview.window(v))
    end)
end)

local function new()
    local zoom = widget{type="label"}
    zoom:hide()
    zoom.fg = theme.sbar_zoom_fg
    zoom.font = theme.sbar_zoom_font
    return wc.add_widget(widgets, zoom)
end

return setmetatable(_M, { __call = function(_, ...) return new(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
