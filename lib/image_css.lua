--- Customize how single images are displayed in the browser.
--
-- @module image_css
-- @copyright 2017 Aidan Holm

local webview = require("webview")
local wm = require_web_module("image_css_wm")

local _M = {}

--- The background color to use when showing images.
_M.background = "#222"

-- Drawn from Firefox's TopLevelImageDocument.css, with some simplifications
local css_tmpl = [===[
    @media not print {
        body {
            margin: 0;
            background-color: {background} !important;
        }

        img {
            text-align: center;
            position: absolute;
            margin: auto;
            top: 0;
            right: 0;
            bottom: 0;
            left: 0;
        }

        /* Prevent clipping the top part of the image */
        img.verticalOverflow {
            margin-top: 0 !important;
        }
    }
]===]

local css = string.gsub(css_tmpl, "{(%w+)}", { background = _M.background })

--- Stylesheet that is applied to webviews that contain only a single image.
_M.stylesheet = stylesheet{ source = css }

webview.add_signal("init", function (view)
    local top_level = {}
    local uri_mime_cache = {}

    view:add_signal("load-status", function (v, status)
        if status == "provisional" then
            top_level[v] = true
        elseif status == "committed" then
            top_level[v] = nil
            local mime = uri_mime_cache[v.uri]
            local is_image = mime and mime:match("^image/")
            view.stylesheets[_M.stylesheet] = is_image
        elseif status == "finished" then
            local mime = uri_mime_cache[v.uri]
            local is_image = mime and mime:match("^image/")
            if is_image then
                wm:emit_signal(view, "image")
            end
        end
    end)

    view:add_signal("mime-type-decision", function (v, uri, mime)
        if top_level[v] then
            uri_mime_cache[uri] = mime
        end
    end)

    local recalc_cb = function (v)
        local w = webview.window(v)
        if w and w.view == v then
            wm:emit_signal(view, "recalc")
        end
    end
    view:add_signal("resize", recalc_cb)
    view:add_signal("switched-page", recalc_cb)
    view:add_signal("property::zoom_level", recalc_cb)
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
