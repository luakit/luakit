--- Web page load progress - status bar widget.
--
-- Shows the load progress of the current web page as a percentage.
--
-- @module lousy.widget.progress
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local webview = require("webview")
local lousy = require("lousy")
local theme = lousy.theme.get()
local wc = require("lousy.widget.common")

local _M = {}

local window = require("window")

local widgets = {
    update = function (w, progress, view)
        view = view or w.view
        if not view then return end
        local p = view.progress
        if not view.is_loading or p == 1 then
            progress:hide()
        else
            progress:show()
            progress.text = string.format("(%d%%)", p * 100)
        end
    end,
}

webview.add_signal("init", function (view)
    -- Update widget when current page changes status
    for _, sig in ipairs({"load-status", "property::progress"}) do
        view:add_signal(sig, function (v)
            local w = webview.window(v)
            if w and w.view == v then
                wc.update_widgets_on_w(widgets, w, v)
            end
        end)
    end
end)


local function new()
    local progress = widget{type="label"}
    progress:hide()
    progress.fg = theme.sbar_loaded_fg
    progress.font = theme.sbar_loaded_font
    return wc.add_widget(widgets, progress)
end

return setmetatable(_M, { __call = function(_, ...) return new(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
