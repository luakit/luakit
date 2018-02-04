--- Window widget
--
-- DOCMACRO(available:ui)
--
-- The window widget is the main container for any windows on the screen.
--
-- @class widget:window
-- @prefix window
-- @author Mason Larobina
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

--- @method set_default_size
-- Set the default size of the window. If this is not called, the default size
-- is 800x600.
-- @tparam integer width The default width of the window, in pixels.
-- @tparam integer height The default height of the window, in pixels.

--- @property title
-- The window title, as displayed on its title bar.
-- @type string
-- @readwrite

--- @property decorated
-- Whether the window is decorated. If the window is decorated, a title bar will
-- be shown. Some window managers permit disabling this decoration, which
-- creates a borderless window.
-- @type boolean
-- @default `true`
-- @readwrite

--- @property urgency_hint
-- Whether the window is requesting the user's attention.
-- @type boolean
-- @default `false`
-- @readwrite

--- @property fullscreen
-- Whether the window is in fullscreen mode.
-- @type boolean
-- @default `false`
-- @readwrite

--- @property maximized
-- Whether the window is maximized.
-- @type boolean
-- @default `false`
-- @readwrite

--- @property id
-- A unique identification number assigned to the window. This number will not
-- be reassigned if the window is closed and another is ooened; new windows
-- will always have new unique identification numbers.
-- @type integer
-- @readonly

--- @property win_xid
-- The window's X11 window ID. Available only when using the X11 windowing system.
-- @type integer
-- @readonly

--- @property root_win_xid
-- The X11 root window's window ID. Available only when using the X11 windowing system.
-- @type integer
-- @readonly

--- @property screen
-- The screen the window is on.
-- @type userdata
-- @readwrite

--- @property icon
-- Path to an image file to set as the window icon.
-- This property can only be set; reading this property always returns `nil`.
-- @type string
-- @readwrite

--- @signal can-close
-- Emitted before a window is closed. Allows Lua code to force the window to
-- remain open.
-- @treturn boolean `true` to allow closing the window, `false` to keep the
-- window open.

--- @signal key-press
-- Emitted when a key is pressed while the window has the input focus.
-- @tparam table modifiers An array of strings, one for each modifier key held.
-- @tparam string key The key that was pressed, if printable, or a keysym
-- otherwise.
-- @treturn boolean `true` if the event has been handled and should not be
-- propagated further.

--- @signal add
-- Emitted when a new widget is set as this widget's child.
-- @tparam widget child The new child widget.

--- @signal remove
-- Emitted when a child widget is removed.
-- @tparam widget child The child widget that was removed.

--- @signal property::*
-- Emitted when some properties change value.

-- vim: et:sw=4:ts=8:sts=4:tw=80
