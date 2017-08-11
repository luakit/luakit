--- Add {A,C,S,}-Return binds to follow selected link (or link in selection).
--
-- This module allows you to follow links that are part of the currently
-- selected text. This is useful as an alternative to the follow mode: search
-- for the text of the link, and then press `<Return>` to follow it.
--
-- @module follow_selected
-- @copyright 2010 Chris van Dijk <quigybo@hotmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2010 Paweł Zuzelski <pawelz@pld-linux.org>
-- @copyright 2009 israellevin

local window = require("window")
local modes = require("modes")
local add_binds = modes.add_binds

local _M = {}

local wm = require_web_module("follow_selected_wm")

local function get_w_by_view_id(view_id)
    for _, w in pairs(window.bywidget) do
        if w.view.id == view_id then
            return w
        end
    end
end

wm:add_signal("navigate", function(_, uri, view_id)
    get_w_by_view_id(view_id):navigate(uri)
end)
wm:add_signal("new_tab", function(_, uri, view_id)
    get_w_by_view_id(view_id):new_tab(uri)
end)
wm:add_signal("new_window", function(_, uri)
    window.new({uri})
end)
wm:add_signal("download", function(_, uri, view_id)
    get_w_by_view_id(view_id):download(uri)
end)

-- Add binding to normal mode to follow selected link
add_binds("normal", {
    { "<Return>", "Follow the selected link in the current tab.",
        function (w) wm:emit_signal(w.view, "follow_selected", "navigate", w.view.id) end },
    { "<Control-Return>", "Follow the selected link in a new tab.",
        function (w) wm:emit_signal(w.view, "follow_selected", "new_tab", w.view.id) end },
    { "<Shift-Return>", "Follow the selected link in a new window.",
        function (w) wm:emit_signal(w.view, "follow_selected", "new_window", w.view.id) end },
    { "<Mod1-Return>", "Download the selected link.",
        function (w) wm:emit_signal(w.view, "follow_selected", "download", w.view.id) end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
