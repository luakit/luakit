--- Basic async test functions.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local T = {}
local test = require "tests.lib"

local window = widget{type="window"}
local view = widget{type="webview"}
window.child = view
window:show()

T.test_about_blank_loads_successfully = function ()
    view.uri = "about:blank"
    test.wait_for_view(view)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
