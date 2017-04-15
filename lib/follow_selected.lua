--- Add {A,C,S,}-Return binds to follow selected link (or link in selection).
--
-- @module follow_selected
-- @copyright 2010 Chris van Dijk (quigybo) <quigybo@hotmail.com>
-- @copyright 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com>
-- @copyright 2010 Paweł Zuzelski (pawelz)  <pawelz@pld-linux.org>
-- @copyright 2009 israellevin

local window = require("window")
local lousy = require("lousy")
local binds = require("binds")
local add_binds = binds.add_binds
local key = lousy.bind.key

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
    key({},          "Return", "Follow the selected link in the current tab.",
        function (w) wm:emit_signal(w.view, "follow_selected", "navigate", w.view.id) end),
    key({"Control"}, "Return", "Follow the selected link in a new tab.",
        function (w) wm:emit_signal(w.view, "follow_selected", "new_tab", w.view.id) end),
    key({"Shift"},   "Return", "Follow the selected link in a new window.",
        function (w) wm:emit_signal(w.view, "follow_selected", "new_window", w.view.id) end),
    key({"Mod1"},    "Return", "Download the selected link.",
        function (w) wm:emit_signal(w.view, "follow_selected", "download", w.view.id) end),
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
