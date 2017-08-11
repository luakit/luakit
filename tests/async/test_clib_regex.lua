--- Test regex clib functionality.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local assert = require "luassert"

local T = {}

T.test_module = function ()
    assert.is_table(regex)
end

T.test_regex_with_no_pattern_fails = function ()
    assert.has_error(function () regex() end)
end

T.test_regex_matches = function ()
    -- Empty string can match ^ and $
    assert(regex{pattern="^"}:match(""))
    assert(regex{pattern="$"}:match(""))

    -- Case sensitive
    assert(not regex{pattern="a"}:match("A"))
    assert(regex{pattern="A"}:match("A"))
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
