-- Zoom level indicator widget.
-- Displays current view zoom level, unless it's 100%.
-- Author: Justin Forest <hex@umonkey.net>

local capi = { luakit = luakit, soup = soup }
local string = string
local theme = theme
local webview = webview
local widget = widget
local window = window


module("plugin.zoomlevel")


-- Create the indicator and add it to the status bar.
local function create_widget(w)
    local r = w.sbar.r

    r.zoom = widget{type="label"}
    r.zoom.fg = theme.sbar_fg
    r.zoom.font = theme.sbar_font

    r.layout:pack(r.zoom)
end


-- Update widget contents.
local function update_zoom_indicator(w)
    if w.view then
        local ctl = w.sbar.r.zoom
        local zl = w.view.zoom_level
        if zl == 1.0 then
            ctl:hide()
        else
            ctl.text = string.format("[zoom:%u%%]", zl * 100)
            ctl:show()
        end
    end
end


-- Set up the indicator and add it to the status bar.
window.init_funcs.build_zoom_level_indicator = function (w)
    create_widget(w)

    w.tabs:add_signal("switch-page", function (nbook, view, idx)
        capi.luakit.idle_add(function()
            update_zoom_indicator(w)
            return false
        end)
    end)
end


-- Refresh the indicator automatically when zoom changes.
-- This is called for all new webviews (tabs or windows).
webview.init_funcs.zoom_indicator_update = function (view, w)
    view:add_signal("property::zoom_level", function (old, new)
        capi.luakit.idle_add(function()
            update_zoom_indicator(w)
            return false
        end)
    end)
end
