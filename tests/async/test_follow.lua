local T = {}
local test = require "tests.lib"
local assert = require "luassert"

uris = { test.http_server() .. "test_follow.html" }
require "config.rc"

local window = require "window"

T.test_follow_mode_shows_hints = function ()
    test.wait_for_idle()
    local w = assert(select(2, next(window.bywidget)))
    w.view.uri = test.http_server() .. "test_follow.html"
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
    w:set_mode()
end

T.test_follow_and_scroll_after_history_back = function ()
    test.wait_for_idle()
    local w = assert(select(2, next(window.bywidget)))
    w.view.uri = test.http_server() .. "test_follow.html"
    test.wait_for_view(w.view)

    local initial_uri = w.view.uri

    -- Navigate cross-domain to another domain (adserver.com)
    w.view.uri = "luakit-test://adserver.com/ad.html"
    test.wait_for_view(w.view)

    -- Go back in history across domains (simulating Ctrl-o)
    w.view:go_back(1)
    test.wait_for_view(w.view)
    assert.is_equal(initial_uri, w.view.uri)

    -- Test follow mode after cross-domain history back navigation
    w:set_mode("follow", {
        selector = "clickable", evaluator = "click",
        func = function (s) w:emit_form_root_active_signal(s) end,
    })
    test.wait_for_idle()
    test.delay(100)

    w.view:eval_js("!!document.getElementById('luakit_select_overlay')", { callback = test.continue })
    local overlay_exists = test.wait()
    assert.is_true(overlay_exists, "overlay element not found in DOM after history back!")

    local js = "document.querySelectorAll('#luakit_select_overlay .hint_overlay').length"
    w.view:eval_js(js, { callback = test.continue })
    local hint_count = test.wait()
    assert.is_equal(3, hint_count, "Expected 3 hint overlays after history back, got " .. tostring(hint_count))
    w:set_mode()
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
