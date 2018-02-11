--- Single-line text entry widget
--
-- DOCMACRO(available:ui)
--
-- The entry widget shows a text box for single-line user input.
--
-- @class widget:entry
-- @prefix entry
-- @author Mason Larobina
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

--- @property position
-- The position of the caret within the entry widget.
-- @type integer
-- @readwrite

--- @property text
-- The contents of the entry widget.
-- @type string
-- @readwrite

--- @property fg
-- The color of the text within the entry widget.
-- @type string
-- @readwrite

--- @property bg
-- The background color of the entry widget.
-- @type string
-- @readwrite

--- @property font
-- The font to use to display the text within the entry widget.
-- @type string
-- @readwrite

--- @property show_frame
-- Whether the frame surrounding the entry widget should be shown.
-- @type boolean
-- @readwrite

--- @method insert
-- Insert text into the entry widget.
-- @tparam[opt] integer position Optional position at which to insert text.
-- Defaults to inserting at the end of any text already in the entry widget.
-- @tparam string text The text to insert.

--- @method select_region
-- Select some or all of the text within the entry widget.
-- @tparam integer startpos The start of the region.
-- @tparam[opt] integer startpos The end of the region. Defaults to the end of
-- the text in the entry widget.

--- @signal activate
-- Emitted when the entry widget is activated by pressing the `Enter` key.

--- @signal changed
-- Emitted when the text within the entry widget changes.

--- @signal property::position
-- Emitted when the position of the caret within the entry widget changes.

--- @signal key-press
-- Emitted when a key is pressed while the entry widget has the input focus.
-- @tparam table modifiers An array of strings, one for each modifier key held.
-- @tparam string key The key that was pressed, if printable, or a keysym
-- otherwise.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

-- vim: et:sw=4:ts=8:sts=4:tw=80
