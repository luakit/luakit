--- Web page scroll position - status bar widget.
--
-- Shows the current scroll position of the web page as a percentage.
--
-- @module lousy.widget.scroll
-- @copyright 2017 Aidan Holm
-- @copyright 2010 Mason Larobina

local window = require("window")
local webview = require("webview")
local lousy = require("lousy")
local theme = lousy.theme.get()

local function update (w)
    w.view:eval_js([=[
        (function () {
            var y = window.scrollY;
            var max = Math.max(window.document.documentElement.scrollHeight - window.innerHeight, 0);
            return y + " " + max;
        })()
    ]=], { callback = function (scroll, err)
        assert(not err, err)
        local y, max = scroll:match("^(%S+) (%S+)$")
        y, max = tonumber(y), tonumber(max)
        local text
        if     max == 0   then text = "All"
        elseif y   == 0   then text = "Top"
        elseif y   == max then text = "Bot"
        else text = string.format("%2d%%", (y / max) * 100)
        end
        local label = w.sbar.r.scroll
        if label.text ~= text then label.text = text end
    end })
end

webview.add_signal("init", function (view)
    view:add_signal("expose", function (v)
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
    local r = w.sbar.r
    r.scroll = widget{type="label"}
    r.layout:pack(r.scroll)

    -- Set style
    r.scroll.fg = theme.scroll_sbar_fg
    r.scroll.font = theme.scroll_sbar_font
end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
