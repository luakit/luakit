--- Test that the default config works.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local T = {}

T.test__config_rc_loads_successfully = function ()
    require "config.rc"
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
