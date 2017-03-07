--- Test test for testing testing.
--
-- @copyright Aidan Holm 2017

local T = {}
local test = require "tests.lib"

T.test_about_blank_loads_successfully = function ()
    local lousy = require "lousy"
    require "globals"
    lousy.theme.init(lousy.util.find_config("theme.lua"))
    assert(lousy.theme.get(), "failed to load theme")
    local window = require "window"
    require "window"
    require "modes"
    local w = window.new({"about:blank"})
    local view = w.view

    repeat
        local _, status = test.wait_for_signal(view, "load-status", 1)
        assert(status ~= "failed")
    until status == "finished"
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
