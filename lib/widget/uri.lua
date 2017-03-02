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
