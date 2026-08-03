--- Web page URI - status bar widget.
--
-- Shows the URI of the current web page. If a link is hovered over with
-- the mouse, the target URI of that link will be shown temporarily.
--
-- @module lousy.widget.uri
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local _M = {}

local webview = require("webview")
local lousy = require("lousy")
local theme = lousy.theme.get()
local wc = require("lousy.widget.common")

local widgets = {
    update = function (w, uri, link, view)
        local text
        if type(link) == "string" then
            text = "Link: " .. link
        else
            view = (type(link) == "widget" and link) or view or w.view
            text = (view and view.uri) or "about:blank"
        end
        uri.text = lousy.util.escape(text)
    end,
}

webview.add_signal("init", function (view)
    view:add_signal("property::uri", function (v)
        local w = webview.window(v)
        if w and w.view == v then
            wc.update_widgets_on_w(widgets, w, nil, v)
        end
    end)
    view:add_signal("link-hover", function (v, link)
        local w = webview.window(v)
        if w and w.view == v and link then
            wc.update_widgets_on_w(widgets, w, link, v)
        end
    end)
    view:add_signal("link-unhover", function (v)
        local w = webview.window(v)
        if w and w.view == v then
            wc.update_widgets_on_w(widgets, w, nil, v)
        end
    end)
end)


local function new()
    local uri = widget{type="label"}
    uri.selectable = true
    uri.can_focus = false
    uri.fg = theme.uri_sbar_fg
    uri.font = theme.uri_sbar_font
    return wc.add_widget(widgets, uri)
end

return setmetatable(_M, { __call = function(_, ...) return new(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
