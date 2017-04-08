--- Check for some memory leaks.
--
-- @copyright Aidan Holm 2017

uris = {"about:blank"}
require "config.rc"

local window = require "window"
local w = assert(select(2, next(window.bywidget)))

local T = {}

T.test_webview_from_closed_tab_is_released = function ()
    local refs = setmetatable({}, { __mode = "k" })
    refs[w.view] = true
    w:close_tab()
    collectgarbage()
    collectgarbage()
    assert(not next(refs), "webview widget not collected")
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
