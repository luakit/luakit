local window = require("window")
local lousy = require("lousy")

local function update (w)
    local buf = w.sbar.r.buf
    if w.buffer then
        buf.text = lousy.util.escape(string.format(" %-3s", w.buffer))
        buf:show()
    else
        buf:hide()
    end
end

window.add_signal("init", function (w)
    -- Add widget to window
    local r = w.sbar.r
    r.buf = widget{type="label"}
    r.layout:pack(r.buf)
    r.buf:hide()

    -- Set style
    r.buf.fg = theme.buf_sbar_fg
    r.buf.font = theme.buf_sbar_font

    -- Update widget when page switched... WHY
    w.tabs:add_signal("switch-page", function ()
        luakit.idle_add(function ()
            update(w)
        end)
    end)
end)

window.methods.update_buf = update
