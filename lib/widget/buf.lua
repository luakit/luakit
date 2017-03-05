--- Input buffer - status bar widget.
--
-- Shows the current contents of the input buffer in the status bar.
--
-- @module widget.buf
-- @copyright 2017 Aidan Holm
-- @copyright 2010 Mason Larobina

local window = require("window")
local lousy = require("lousy")
local theme = lousy.theme.get()

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
end)

window.methods.update_buf = update
