local T = {}
local test = require "tests.lib"
local assert = require "luassert"

uris = { test.http_server() .. "test_follow.html" }
require "config.rc"

local window = require "window"

T.test_follow_mode_shows_hints = function ()
    test.wait_for_idle()
    local w = assert(select(2, next(window.bywidget)))
    test.wait_for_view(w.view)

    -- Enter follow mode
    w:set_mode("follow", {
        selector = "clickable", evaluator = "click",
        func = function (s) w:emit_form_root_active_signal(s) end,
    })

    test.wait_for_idle()

    -- Check if the prompt text is "Follow:"
    assert.is_equal("Follow:", w.ibar.prompt.text)

    -- Wait for hints to be generated in WebProcess
    test.delay(100)

    -- Wait a bit for hints to be generated in WebProcess
    w.view:eval_js("!!document.getElementById('luakit_select_overlay')", { callback = test.continue })
    local overlay_exists = test.wait()
    assert.is_true(overlay_exists, "luakit_select_overlay element not found in DOM!")

    -- Check if we have hint overlay elements inside the overlay
    local js = "document.querySelectorAll('#luakit_select_overlay .hint_overlay').length"
    w.view:eval_js(js, { callback = test.continue })
    local hint_count = test.wait()
    assert.is_equal(3, hint_count, "Expected 3 hint overlays, but got " .. tostring(hint_count))
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
