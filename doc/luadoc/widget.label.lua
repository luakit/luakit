--- Label widget
--
-- DOCMACRO(available:ui)
--
-- The label widget shows a single line of formatted text. It is not editable by the
-- user.
--
-- @class widget:label
-- @prefix label
-- @author Mason Larobina
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

--- @property padding
-- The widget padding. Table has two fields, `x` and `y`, representing the
-- vertical and horizontal padding respectively, in pixels.
--
-- Available only for older versions of GTK (< 2.14).
-- @type table
-- @readwrite

--- @property align
-- The text alignment. Table has two fields, `x` and `y`, representing the
-- vertical and horizontal alignment respectively. Values should be between
-- 0--1, where 0 means aligned to the left/top, and 1 means aligned to the
-- right/bottom.
-- @type table
-- @readwrite

--- @property text
-- Text to display in the widget. This property uses Pango markup.
-- @type string
-- @readwrite

--- @property fg
-- The color of the text displayed by the widget. This can be changed with
-- markup set by the @ref{widget:label/text} property.
-- @type string
-- @readwrite

--- @property bg
-- The background color of the label widget.
-- @type string
-- @readwrite

--- @property font
-- The font to use to display the label text.
-- @type string
-- @readwrite

--- @property selectable
-- Whether the text can be selected by dragging with the mouse cursor.
-- @type boolean
-- @readwrite
-- @default `false`

--- @property textwidth
-- The desired width of the label, in characters.
-- @type integer
-- @readwrite

--- @signal key-press
-- Emitted when a key is pressed while the label widget has the input focus.
-- @tparam table modifiers An array of strings, one for each modifier key held.
-- @tparam string key The key that was pressed, if printable, or a keysym
-- otherwise.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

-- vim: et:sw=4:ts=8:sts=4:tw=80
