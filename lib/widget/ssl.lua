--- Web page security - ssl status bar widget.
--
-- Indicates whether the connection used to load the current web page
-- was secure.
--
-- @module widget.ssl
-- @copyright 2017 Aidan Holm
-- @copyright 2010 Mason Larobina

local window = require("window")
local webview = require("webview")
local lousy = require("lousy")
local theme = lousy.theme.get()

local function update (w)
    local trusted = w.view:ssl_trusted()
    local ssl = w.sbar.r.ssl
    if trusted == true then
        ssl.fg = theme.trust_fg
        ssl.text = "(trust)"
        ssl:show()
    elseif string.sub(w.view.uri or "", 1, 4) == "http" then
        -- Display (notrust) on http/https URLs
        ssl.fg = theme.notrust_fg
        ssl.text = "(notrust)"
        ssl:show()
    end
end

webview.add_signal("init", function (view)
    -- Update widget when current page changes status
    for _, sig in ipairs({"load-status", "property::progress"}) do
        view:add_signal(sig, function (v)
            local w = webview.window(v)
            if w.view == v then
                update(w)
            end
        end)
    end
    view:add_signal("switched-page", function (v)
        update(webview.window(v))
    end)
end)

window.add_signal("init", function (w)
    -- Add widget to window
    local r = w.sbar.r
    r.ssl = widget{type="label"}
    r.layout:pack(r.ssl)
    r.ssl:hide()

    -- Set style
    r.ssl.fg = theme.ssl_sbar_fg
    r.ssl.font = theme.ssl_sbar_font
end)
