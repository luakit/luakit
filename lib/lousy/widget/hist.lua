--- Web page history - status bar widget.
--
-- Indicates whether the current page can go back or go forward.
--
-- The widget will not be shown if the current page cannot go back or forward.
--
-- @module lousy.widget.hist
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local webview = require("webview")
local lousy = require("lousy")
local theme = lousy.theme.get()
local wc = require("lousy.widget.common")

local _M = {}

--- Format string which defines the appearance of the widget.
-- The text `{back}` is replaced with the back indicator, and the text
-- `{forward}` is replaced with the forward indicator.
-- @type string
-- @readwrite
_M.format = "[{back}{forward}]"

--- Text used to indicate that the current page can go back.
-- @type string
-- @readwrite
_M.back_indicator = "+"

--- Text used to indicate that the current page can go forward.
-- @type string
-- @readwrite
_M.forward_indicator = "-"

local widgets = {
    update = function (w, hist)
        local back, forward = w.view:can_go_back(), w.view:can_go_forward()
        if back or forward then
            hist.text  = string.gsub(_M.format, "{(%w+)}", {
                back = back and _M.back_indicator or "",
                forward = forward and _M.forward_indicator or "",
            })
            hist:show()
        else
            hist:hide()
        end
    end,
}

webview.add_signal("init", function (view)
    -- Update widget when current page changes status
    view:add_signal("load-status", function (v)
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
    local hist = widget{type="label"}
    hist:hide()
    hist.fg = theme.hist_sbar_fg
    hist.font = theme.hist_sbar_font
    return wc.add_widget(widgets, hist)
end

return setmetatable(_M, { __call = function(_, ...) return new(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
