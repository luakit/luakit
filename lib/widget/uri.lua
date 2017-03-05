--- Web page URI - status bar widget.
--
-- Shows the URI of the current web page. If a link is hovered over with
-- the mouse, the target URI of that link will be shown temporarily.
--
-- @module widget.uri
-- @copyright 2017 Aidan Holm
-- @copyright 2010 Mason Larobina

local window = require("window")
local webview = require("webview")
local lousy = require("lousy")
local theme = lousy.theme.get()

local function update (w, link)
    w.sbar.l.uri.text = lousy.util.escape((link and "Link: " .. link)
        or (w.view and w.view.uri) or "about:blank")
end

webview.add_signal("init", function (view)
    view:add_signal("property::uri", function (v)
        local w = webview.window(v)
        if w.view == v then
            update(w)
        end
    end)
    view:add_signal("link-hover", function (v, link)
        local w = webview.window(v)
        if w.view == v and link then
            update(w, link)
        end
    end)
    view:add_signal("link-unhover", function (v)
        local w = webview.window(v)
        if w.view == v then
            update(w)
        end
    end)
    view:add_signal("switched-page", function (v)
        update(webview.window(v))
    end)
end)

window.add_signal("init", function (w)
    -- Add widget to window
    local l = w.sbar.l
    l.uri = widget{type="label"}
    l.layout:pack(l.uri)
    l.uri.selectable = true

    -- Set style
    l.uri.fg = theme.uri_sbar_fg
    l.uri.font = theme.uri_sbar_font
end)
