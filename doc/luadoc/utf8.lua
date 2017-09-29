--- Basic UTF8 character counting support for Luakit.
--
-- @class utf8
-- @author Dennis Hofheinz
-- @copyright 2017 Dennis Hofheinz <github@kjdf.de>

--- @method len
-- Return the length (in UTF8 characters) of a string.
-- If optional parameters `begin` and/or `end` are given, return only the number of valid UTF8 characters that start in the slice from byte position `begin` up to (and including) `end`.
-- An error is raised if `string` (or the characters that start in the slice from `begin` to `end`) contains invalid UTF8 characters, of if `begin` or `end` point to byte indices not in `string`.
-- @tparam string string The string whose length is to be returned.
-- @tparam[opt] integer begin Only consider `string` from (1-based byte) index `begin` onwards. If negative, count from `end` of `string` (with -1 being the last byte). Defaults to 1 if omitted.
-- @tparam[opt] integer end Only consider `string` up to and including (1-based byte) index `end`. If negative, count from `end` of `string` (with -1 being the last byte). Defaults to -1 if omitted.
-- @treturn integer The length (in UTF8 characters) of `string`.

--- @method offset
-- Convert an offset (in UTF8 characters) to a byte offset.
-- If optional parameter `base` is given and positive, count characters starting from (byte) index `base`.
-- Hence, `utf8.offset("abc",2,2)` would return `3`, while `utf8.offset("abc",-3)` would return `1`.
-- An error is raised if base is smaller than `1` or larger than the (byte) length of `string`, or if `base` points to a byte inside `string` that is not the starting byte of a UTF8 encoding.
-- @tparam string string The string in which offsets should be converted.
-- @tparam integer woffset The offset (1-based, in UTF8 characters) which should be converted.
-- @tparam[opt] integer base A (1-based byte) index in `string`. Defaults to 1 if `woffset` is positive, and to the (byte) length of `string` if `woffset` is negative. See the description above.
-- @treturn integer The (1-based) byte offset of the `woffset`-th UTF8 character in `string`.

-- vim: et:sw=4:ts=8:sts=4:tw=80
