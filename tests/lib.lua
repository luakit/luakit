--- Testing interface.
--
-- @module tests.lib
-- @copyright 2017 Aidan Holm

local _M = {}

function _M.fail(msg)
    error(msg, 0)
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
