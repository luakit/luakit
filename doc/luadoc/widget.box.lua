--- Box widget
--
-- DOCMACRO(available:ui)
--
-- The box widget allows stacking widgets horizontally or vertically.
--
-- @class widget:box
-- @prefix box
-- @author Mason Larobina
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

--- @method pack
-- Add a widget to the box. There are several valid options that can be set in
-- an options table:
--
--  - `from`: whether to add child to the start or the end of the box. Can be
--  `"start"` or `"end"`.
--  - `expand`: whether the new child should be assigned any extra space; such
--  space is divided among all children with `expand` set to `true`.
--  - `fill`: if `true`, the child will expand to fill any extra space assigned
--  to it; otherwise, the child will be centered within the extra space.
--  - `padding`: Extra space to put between the new child and its neighbors or
--  the ends of the box widget, in pixels.
-- @tparam widget child The widget to add as a new child.
-- @tparam table|nil options Table of options.

--- @method reorder_child
-- Rearrange a widget already in the box.
-- @tparam widget child The child widget to reorder.
-- @tparam integer position The position to move the widget to.

--- @property homogeneous
-- Whether the child widgets should all have the same size.
-- @type boolean
-- @readwrite
-- @default `false`

--- @property spacing
-- The amount of space between each of the child widgets. Must be non-negative.
-- @type number
-- @readwrite
-- @default 0

--- @property bg
-- The background color of the box widget.
-- @type string|nil
-- @readwrite

-- vim: et:sw=4:ts=8:sts=4:tw=80
