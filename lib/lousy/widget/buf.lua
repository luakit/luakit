--- Input buffer - status bar widget.
--
-- Shows the current contents of the input buffer in the status bar.
--
-- @module lousy.widget.buf
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local window = require("window")
local lousy = require("lousy")
local theme = lousy.theme.get()
local wc = require("lousy.widget.common")

local _M = {}

local widgets = {
    update = function (w, buf)
        if w.buffer then
            buf.text = lousy.util.escape(string.format(" %-3s", w.buffer))
            buf:show()
        else
            buf:hide()
        end
    end,
}

local function new()
    local buf = widget{type="label"}
    buf:hide()
    buf.fg = theme.buf_sbar_fg
    buf.font = theme.buf_sbar_font
    return wc.add_widget(widgets, buf)
end

window.methods.update_buf = function (w) wc.update_widgets_on_w(widgets, w) end

return setmetatable(_M, { __call = function(_, ...) return new(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80
