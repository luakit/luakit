--- Hide scrollbars.
--
-- Hides all element scrollbars. Elements can still be scrolled as usual.
--
-- @module hide_scrollbars
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

local webview = require("webview")

local _M = {}

local disable_scrollbar_ss = stylesheet{ source = [===[
    ::-webkit-scrollbar {
        width: 0 !important;
        height: 0 !important;
    }
]===] }

webview.add_signal("init", function (view)
    view.stylesheets[disable_scrollbar_ss] = true
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
