--- Common functions for implementing widgets.
--
-- @module lousy.widget.common
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local window = require("window")
local lousy = require("lousy")

local _M = {}

--- Add `widget` to `widgets`, and automatically remove it when `widget` is
-- destroyed.
-- @tparam table widgets A table of widgets
-- @tparam widget widget A newly-created widget
-- @return Returns `widget`, to allow easy chaining.
_M.add_widget = function (widgets, widget)
    assert(type(widgets) == "table")
    table.insert(widgets, widget)
    widget:add_signal("destroy", function (wi)
        table.remove(widgets, lousy.util.table.hasitem(widgets, wi))
    end)
    return widget
end

--- Update all widgets in `widgets` on the given window.
-- @tparam table widgets A table of widgets
-- @tparam table w A window table
_M.update_widgets_on_w = function (widgets, w, ...)
    assert(type(widgets) == "table")
    assert(w.win.type == "window")
    for _, widget in ipairs(widgets) do
        if window.ancestor(widget) == w then
            widgets.update(w, widget, ...)
        end
    end
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
