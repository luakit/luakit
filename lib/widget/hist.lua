local window = require("window")
local webview = require("webview")
local lousy = require("lousy")
local theme = lousy.theme.get()

local function update (w)
    local hist = w.sbar.l.hist
    local back, forward = w.view:can_go_back(), w.view:can_go_forward()
    local s = (back and "+" or "") .. (forward and "-" or "")
    if s ~= "" then
        hist.text = '['..s..']'
        hist:show()
    else
        hist:hide()
    end
end

webview.add_signal("init", function (view)
    -- Update widget when current page changes status
    view:add_signal("load-status", function (v)
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
    l.hist = widget{type="label"}
    l.layout:pack(l.hist)
    l.hist:hide()

    -- Set style
    l.hist.fg = theme.hist_sbar_fg
    l.hist.font = theme.hist_sbar_font
end)
