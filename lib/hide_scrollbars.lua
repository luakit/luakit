--- Hide scrollbars.
--
-- @module hide_scrollbars
-- @copyright 2016 Aidan Holm

local webview = require("webview")

local _M = {}

local disable_scrollbar_ss = stylesheet{ source = [===[
    ::-webkit-scrollbar {
        width: 0 !important;
        height: 0 !important;
    }
]===] }

webview.init_funcs.hide_scrollbars = function (v)
    v.stylesheets[disable_scrollbar_ss] = true
end

return _M
