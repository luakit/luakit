--- Notebook widget
--
-- DOCMACRO(available:ui)
--
-- The notebook widget allows switching between a set of widgets, only one of
-- which will be visible at a given time.
--
-- @class widget:notebook
-- @prefix notebook
-- @author Mason Larobina
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

--- @method count
-- Get the number of pages in the notebook.
-- @treturn integer The number of pages in the notebook.

--- @method current
-- Get the page number of the currently visible page.
-- @treturn integer The 1-based index of the currently visible page.

--- @method get_title
-- Get the tab label text for a particular child widget.
-- @tparam widget child The child widget.

--- @method set_title
-- Set the tab label text for a particular child widget.
-- @tparam widget child The child widget.
-- @tparam string title The new tab label text.

--- @method indexof
-- Get the page number of the given child widget.
-- @tparam widget child The child widget.
-- @treturn integer The 1-based index of the child widget.

--- @method insert
-- Add a new child widget to the notebook, adding a new page.
-- @tparam[opt] integer index Position to add the widget. Defaults to adding at the
-- end.
-- @tparam widget child The new child widget to add.

--- @method switch
-- Switch to a notebook page.
-- @tparam integer index The 1-based index of the page to switch to.

--- @method reorder
-- Move a given child widget to a different position.
-- @tparam widget child The child widget.
-- @tparam integer index The 1-based index of the new page number, or -1 to move it to
-- the last position.

--- @property show_tabs
-- Whether a row of tabs will be shown above the notebook pages.
-- @type boolean
-- @readwrite
-- @default `true`

--- @property show_border
-- Whether a border will be shown around the notebook pages.
-- @type boolean
-- @readwrite
-- @default `false`

--- @signal key-press
-- Emitted when a key is pressed while the notebook widget has the input focus.
-- @tparam table modifiers An array of strings, one for each modifier key held.
-- @tparam string key The key that was pressed, if printable, or a keysym
-- otherwise.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

--- @signal page-added
-- Emitted immediately after a new widget is added to the notebook, adding a new page.
-- @tparam widget child The new child widget.
-- @tparam integer index The 1-based page index of the new child widget.

--- @signal page-removed
-- Emitted immediately after a widget is removed from the notebook, removing a page.
-- @tparam widget child The child widget that was removed.

--- @signal page-reordered
-- Emitted immediately after a notebook page has been reordered.
-- @tparam widget child The child widget that was reordered.
-- @tparam integer index The new 1-based page index of the child widget.

--- @signal switch-page
-- Emitted when the currently visible page of the notebook is changed.
-- @tparam widget child The child widget that is being switched to.
-- @tparam integer index The 1-based index of the page that is being switched to.

-- vim: et:sw=4:ts=8:sts=4:tw=80
