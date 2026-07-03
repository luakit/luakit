--- Tab position - status bar widget.
--
-- Shows the number of the current tab, as well as the total number of
-- tabs in the window.
--
-- @module lousy.widget.tabi
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local window = require("window")
local webview = require("webview")
local lousy = require("lousy")
local theme = lousy.theme.get()
local wc = require("lousy.widget.common")

local _M = {}

local widgets = {
    update = function (w, tabi, view, index)
        index = index or w.tabs:current()
        tabi.text = string.format("[%d/%d]", index, w.tabs:count())
    end,
}


local function new()
    local tabi = widget{type="label"}
    tabi.fg = theme.tabi_sbar_fg
    tabi.font = theme.tabi_sbar_font
    return wc.add_widget(widgets, tabi)
end

return setmetatable(_M, { __call = function(_, ...) return new(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
