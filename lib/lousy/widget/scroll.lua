--- Web page scroll position - status bar widget.
--
-- Shows the current scroll position of the web page as a percentage.
--
-- @module lousy.widget.scroll
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local webview = require("webview")
local lousy = require("lousy")
local theme = lousy.theme.get()
local wc = require("lousy.widget.common")

local _M = {}

local widgets = {
    update = function (w, label, view)
        view = view or w.view
        if not view then return end
        local scroll = view.scroll
        if not scroll then return end
        local y, max = scroll.y, scroll.ymax
        if not y or not max then return end
        local text
        if     max <= 0   then text = "All"
        elseif y   <= 2   then text = "Top"
        elseif y   >= (max - 2) then text = "Bot"
        else text = string.format("%2d%%", (y / max) * 100)
        end
        if label.text ~= text then label.text = text end
    end,
}

webview.add_signal("init", function (view)
    view:add_signal("scroll", function (v)
        local w = webview.window(v)
        if w and w.view == v then
            wc.update_widgets_on_w(widgets, w, v)
        end
    end)
end)

local function new()
    local scroll = widget{type="label"}
    scroll.fg = theme.scroll_sbar_fg
    scroll.font = theme.scroll_sbar_font
    return wc.add_widget(widgets, scroll)
end

return setmetatable(_M, { __call = function(_, ...) return new(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
