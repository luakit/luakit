--- Test that the default config works.
--
-- @copyright Aidan Holm 2017

local T = {}

T.test__config_rc_loads_successfully = function ()
    require "config.rc"
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
