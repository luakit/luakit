--- Drawing area widget
--
-- DOCMACRO(available:ui)
--
-- The drawing area widget allows drawing from Cairo via the LuaJIT FFI.
--
-- Widgets of this type cannot be created without LuaJIT FFI support.
--
-- @class widget:drawing_area
-- @prefix area
-- @author Aidan Holm
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

--- @method invalidate
-- Invalidates the drawing area and queues a redraw.

--- @signal draw
-- This signal is emitted when the contents of the drawing area need to be
-- redrawn, using the provided Cairo drawing context.
-- @tparam cairo context A FFI wrapper to a `cairo_t *` type.

-- vim: et:sw=4:ts=8:sts=4:tw=80
