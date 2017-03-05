--- Tab position - status bar widget.
--
-- Shows the number of the current tab, as well as the total number of
-- tabs in the window.
--
-- @module widget.tabi
-- @copyright 2017 Aidan Holm
-- @copyright 2010 Mason Larobina

local window = require("window")
local webview = require("webview")
local lousy = require("lousy")
local theme = lousy.theme.get()

local function update (w)
    w.sbar.r.tabi.text = string.format("[%d/%d]", w.tabs:current(), w.tabs:count())
end

webview.add_signal("init", function (view)
    -- Update widget when current page changes status
    view:add_signal("switched-page", function (v)
        local w = webview.window(v)
        update(w)
    end)
end)

window.add_signal("init", function (w)
    -- Add widget to window
    local r = w.sbar.r
    r.tabi = widget{type="label"}
    r.layout:pack(r.tabi)

    -- Set style
    r.tabi.fg = theme.tabi_sbar_fg
    r.tabi.font = theme.tabi_sbar_font

    w.tabs:add_signal("page-added", function ()
        luakit.idle_add(function ()
            update(w)
        end)
    end)
    w.tabs:add_signal("page-reordered", function ()
        update(w)
    end)
end)
