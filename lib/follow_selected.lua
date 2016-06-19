------------------------------------------------------------------------------
-- Add {A,C,S,}-Return binds to follow selected link (or link in selection) --
-- © 2010 Chris van Dijk (quigybo) <quigybo@hotmail.com>                    --
-- © 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com>               --
-- © 2010 Paweł Zuzelski (pawelz)  <pawelz@pld-linux.org>                   --
-- © 2009 israellevin                                                       --
------------------------------------------------------------------------------

local web_module = web_module
local window = window
local assert = assert
local pairs = pairs
local key = lousy.bind.key
local add_binds = add_binds

module("follow_selected")

local wm = web_module("follow_selected_webmodule")

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
wm:add_signal("new_window", function(_, uri, view_id)
    window.new({uri})
end)
wm:add_signal("download", function(_, uri, view_id)
    get_w_by_view_id(view_id):download(uri)
end)

-- Add binding to normal mode to follow selected link
add_binds("normal", {
    key({},          "Return", function (w) wm:emit_signal("follow_selected", "navigate", w.view.id) end),
    key({"Control"}, "Return", function (w) wm:emit_signal("follow_selected", "new_tab", w.view.id) end),
    key({"Shift"},   "Return", function (w) wm:emit_signal("follow_selected", "new_window", w.view.id) end),
    key({"Mod1"},    "Return", function (w) wm:emit_signal("follow_selected", "download", w.view.id) end),
})
-- vim: et:sw=4:ts=8:sts=4:tw=80
