--- Socket widget
--
-- DOCMACRO(available:ui)
--
-- The socket widget allows displaying a window from an XEMBED client within the
-- luakit user interface.
--
-- @class widget:socket
-- @prefix socket
-- @author Mason Larobina
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

--- @property id
-- When reading, this returns the window ID of this socket widget.
-- When writing, this adds an XEMBED client with the given window ID to the
-- socket.
-- @type integer
-- @readwrite

--- @property plugged
-- Whether a client window is currently plugged into this socket.
-- @type boolean
-- @readonly

--- @signal plug-added
-- Emitted when a client window is added to the socket.

--- @signal plug-removed
-- Emitted when a client window is removed from the socket.

-- vim: et:sw=4:ts=8:sts=4:tw=80
