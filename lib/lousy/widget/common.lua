--- Common functions for implementing widgets.
--
-- @module lousy.widget.common
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local window = require("window")

local _M = {}

local all_widget_groups = {}

--- Add `widget` to `widgets`, and automatically remove it when `widget` is
-- destroyed.
-- @tparam table widgets A table of widgets
-- @tparam widget widget A newly-created widget
-- @return Returns `widget`, to allow easy chaining.
_M.add_widget = function (widgets, widget)
    assert(type(widgets) == "table")
    table.insert(widgets, widget)
    local found = false
    for _, g in ipairs(all_widget_groups) do
        if g == widgets then
            found = true
            break
        end
    end
    if not found then
        table.insert(all_widget_groups, widgets)
    end
    return widget
end

--- Update all widgets in `widgets` on the given window.
-- @tparam table widgets A table of widgets
-- @tparam table w A window table
_M.update_widgets_on_w = function (widgets, w, ...)
    assert(type(widgets) == "table")
    assert(w.win.type == "window")
    for i = #widgets, 1, -1 do
        local widget = widgets[i]
        if not widget.is_alive then
            table.remove(widgets, i)
        elseif window.ancestor(widget) == w then
            widgets.update(w, widget, ...)
        end
    end
end

--- Update all widgets on the given window across all widget groups.
-- @tparam table w A window table
_M.update_all_widgets_on_w = function (w, ...)
    for _, widgets in ipairs(all_widget_groups) do
        _M.update_widgets_on_w(widgets, w, ...)
    end
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
