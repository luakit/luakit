--- Web page load progress - status bar widget.
--
-- Shows the load progress of the current web page as a percentage.
--
-- @module widget.progress
-- @copyright 2017 Aidan Holm
-- @copyright 2010 Mason Larobina

local window = require("window")
local webview = require("webview")
local lousy = require("lousy")
local theme = lousy.theme.get()

local function update (w)
    local p = w.view.progress
    local progress = w.sbar.l.progress
    if not w.view.is_loading or p == 1 then
        progress:hide()
    else
        progress:show()
        progress.text = string.format("(%d%%)", p * 100)
    end
end

webview.add_signal("init", function (view)
    -- Update widget when current page changes status
    for _, sig in ipairs({"load-status", "property::progress"}) do
        view:add_signal(sig, function (v)
            local w = webview.window(v)
            if w.view == v then
                update(w)
            end
        end)
    end
    view:add_signal("switched-page", function (v)
        update(webview.window(v))
    end)
end)

window.add_signal("init", function (w)
    -- Add widget to window
    local l = w.sbar.l
    l.progress = widget{type="label"}
    l.layout:pack(l.progress)
    l.progress:hide()

    -- Set style
    l.progress.fg = theme.sbar_loaded_fg
    l.progress.font = theme.sbar_loaded_font
end)
