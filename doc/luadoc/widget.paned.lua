--- Paned widget
--
-- DOCMACRO(available:ui)
--
-- The paned widget provides a two-pane interface widget, with a
-- draggable slider between panes.
--
-- @class widget:paned
-- @prefix paned
-- @author Mason Larobina
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

--- @method pack1
-- Add a widget to the left/top panel. There are two options that can be set:
--
-- - `resize`: whether the new child widget should be resized as the
--   pane is resized.
-- - `shrink`: whether the new child widget should be shrunk smaller
--   than its default size.
--
-- @tparam widget child The widget to add as a new child.
-- @tparam table|nil options Table of options.

--- @method pack2
-- Add a widget to the right/bottom panel. Otherwise the same as `pack1()`.
-- @tparam widget child The widget to add as a new child.
-- @tparam table|nil options Table of options.

--- @property top
-- The top/left pane child widget.
-- @type widget
-- @readonly

--- @property left
-- The top/left pane child widget.
-- @type widget
-- @readonly

--- @property bottom
-- The bottom/right pane child widget.
-- @type widget
-- @readonly

--- @property right
-- The bottom/right pane child widget.
-- @type widget
-- @readonly

--- @property position
-- The current position of the divider, in pixels.
-- @type number
-- @readwrite

-- vim: et:sw=4:ts=8:sts=4:tw=80
