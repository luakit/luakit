--- Tests for the input completions module.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local T = {}
local assert = require("luassert")

uris = {"about:blank"}
require "config.rc"

local window = require "window"
local w = assert(select(2, next(window.bywidget)))

T.test_leaving_completion_restores_correct_input_text = function ()
    local input = w.ibar.input

    w:enter_cmd(":tab")
    w:set_mode("completion")
    w.menu:move_up()
    assert.equal(":tab", input.text)

    input.text = ":adbl"
    w.menu:move_down()
    w.menu:move_up()
    assert.equal(":adbl", input.text)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
