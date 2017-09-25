--- Test utf8 clib functionality.
--
-- @copyright 2017 Dennis Hofheinz <github@kjdf.de>

local assert = require "luassert"

local T = {}

T.test_module = function ()
    assert.is_table(utf8)
end

T.test_utf8_len = function ()
    assert(utf8.len("")==0)
    assert(utf8.len("ä")==1)
    assert(utf8.len("äa")==2)
end

T.test_utf8_offset = function ()
    assert(utf8.offset("äaäaä",1)==1)
    assert(utf8.offset("äaäaä",2)==3)
    assert(utf8.offset("äaäaä",5)==7)
    assert(utf8.offset("äaäaä",6)==9)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
