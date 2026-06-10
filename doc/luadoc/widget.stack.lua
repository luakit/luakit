--- Stack widget
--
-- DOCMACRO(available:ui)
--
-- The stack widget allows switching between a set of widgets, only one of
-- which will be visible at a given time. Unlike the notebook widget, a stack
-- does not show a tab bar, but switches children programmatically.
--
-- @class widget:stack
-- @prefix stack

--- @method pack
-- Add a widget to the stack.
-- @tparam widget child The child widget to add.

--- @property homogeneous
-- Whether the stack allocates the same size for all children.
-- @type boolean
-- @readwrite
-- @default `true`

--- @property visible_child
-- The child widget currently visible in the stack.
-- @type widget
-- @readwrite

-- vim: et:sw=4:ts=8:sts=4:tw=80
