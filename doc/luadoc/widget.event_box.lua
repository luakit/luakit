--- Event Box widget
--
-- DOCMACRO(available:ui)
--
-- The event box widget allows stacking widgets horizontally or vertically.
--
-- @class widget:event_box
-- @prefix ebox
-- @author Mason Larobina
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

--- @property bg
-- The background color of the box widget.
-- @type string|nil
-- @readwrite

--- @signal add
-- Emitted when a new widget is set as this widget's child.
-- @tparam widget child The new child widget.

--- @signal button-press
-- Emitted when a mouse button was pressed with the cursor inside the event box widget.
--
-- @tparam table modifiers An array of strings, one for each modifier key held
-- at the time of the event.
-- @tparam integer button The number of the button pressed, beginning
-- from `1`; i.e. `1` corresponds to the left mouse button.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

--- @signal button-release
-- Emitted when a mouse button was released with the cursor inside the event box widget.
--
-- @tparam table modifiers An array of strings, one for each modifier key held
-- at the time of the event.
-- @tparam integer button The number of the button pressed, beginning
-- from `1`; i.e. `1` corresponds to the left mouse button.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

--- @signal button-double-click
-- Emitted when a mouse button was double-clicked with the cursor inside the event box widget.
--
-- @tparam table modifiers An array of strings, one for each modifier key held
-- at the time of the event.
-- @tparam integer button The number of the button pressed, beginning
-- from `1`; i.e. `1` corresponds to the left mouse button.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

--- @signal mouse-enter
-- Emitted when the mouse cursor enters the event box widget.
-- @tparam table modifiers An array of strings, one for each modifier key held.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

--- @signal mouse-leave
-- Emitted when the mouse cursor leaves the event box widget.
-- @tparam table modifiers An array of strings, one for each modifier key held.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

-- vim: et:sw=4:ts=8:sts=4:tw=80
