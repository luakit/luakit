--- Basic UTF8 character counting support for Luakit.
--
-- @class utf8
-- @author Dennis Hofheinz
-- @copyright 2017 Dennis Hofheinz <github@kjdf.de>

--- @method len
-- Return the length (in UTF8 characters) of a string.
-- @tparam string string The string whose length is to be returned.
-- @treturn integer The length of that string.

--- @method offset
-- Convert an offset (in UTF8 characters) to a byte offset.
-- @tparam string string The string in which offsets should be converted.
-- @tparam integer utf8_offset The offset (in UTF8 characters) which should be converted. The first character has offset 1.
-- @treturn integer The byte offset of that string. An offset of 1 denotes the first character.

-- vim: et:sw=4:ts=8:sts=4:tw=80
