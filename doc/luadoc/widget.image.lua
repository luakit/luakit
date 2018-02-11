--- Image widget
--
-- DOCMACRO(available:ui)
--
-- The image widget shows an image from a website favicon, a file, or an icon
-- name.
--
-- @class widget:image
-- @prefix image
-- @author Aidan Holm
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

--- @method filename
-- Show an image from a file. On HiDPI screens, a file with "@2x" before
-- the extension will be used instead, if it is present.
--
-- The filename is used to search the directories specified by @ref{luakit/resource_path}.
-- @tparam string path The path to the image file.

--- @method icon
-- Show a named icon.
-- @tparam string name The name of the icon to use.
-- @tparam integer size The size at which to display the icon, in pixels; must be one of
-- 16, 24, 32, or 48.

--- @method scale
-- Scale the current image to a certain size.
-- @tparam integer width The width to scale to, in pixels.
-- @tparam[opt] integer height The height to scale to, in pixels. If omitted, the desired width is used for the height as well.

--- @method set_favicon_for_uri
-- Show the favicon for the given URI, if it has one, at a size of 16x16 pixels.
-- @tparam string uri The URI.
-- @treturn boolean `true` if the favicon was successfully shown.

-- vim: et:sw=4:ts=8:sts=4:tw=80
