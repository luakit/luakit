local webview = require("webview")
local stylesheet = stylesheet

module("hide_scrollbars")

local disable_scrollbar_ss = stylesheet{ source = [===[
    ::-webkit-scrollbar {
        width: 0 !important;
        height: 0 !important;
    }
]===] }

webview.init_funcs.hide_scrollbars = function (v)
    v.stylesheets[disable_scrollbar_ss] = true
end
