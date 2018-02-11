--- Regex support
-- @class regex
-- @author Aidan Holm
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
--
-- # Creating a new regex instance
--
-- To create a new regex instance, use the `regex` constructor:
--
--     local reg = regex{ pattern = "[1-9][0-9]*" }
--
-- 	assert(reg:match("7392473"))

--- @method match
-- Scan a given string for a match.
-- @tparam string string The string to scan for a match.
-- @treturn boolean `true` if a match was found, `false` otherwise.

-- vim: et:sw=4:ts=8:sts=4:tw=80
