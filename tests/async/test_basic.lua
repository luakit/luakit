--- Basic async test functions.
--
-- @copyright Aidan Holm 2017

local T = {}
local test = require "tests.lib"

local window = widget{type="window"}
local view = widget{type="webview"}
window.child = view
window:show()

T.test_about_blank_loads_successfully = function ()
    view.uri = "about:blank"
    repeat
        local _, status = test.wait_for_signal(view, "load-status", 1)
        assert(status ~= "failed")
    until status == "finished"
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
