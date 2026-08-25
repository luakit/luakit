local T = {}
local test = require "tests.lib"
local assert = require "luassert"

uris = { test.http_server() .. "test_follow.html" }
require "config.rc"

local window = require "window"

local initial_loaded = false
local function ensure_initial_page(w)
    test.wait_for_idle()
    if not initial_loaded then
        test.wait_for_view(w.view)
        initial_loaded = true
    end
end

T.test_follow_mode_shows_hints = function ()
    local w = assert(select(2, next(window.bywidget)))
    ensure_initial_page(w)
    local page_uri = test.http_server() .. "test_follow.html"
    if w.view.uri ~= page_uri then
        w.view.uri = page_uri
        test.wait_for_view(w.view)
    end

    -- Enter follow mode
    w:hit({}, "f")
    test.wait_for_idle()
    test.delay(300)

    -- Check if the prompt text is "Follow:"
    assert.is_equal("Follow:", w.ibar.prompt.text)

    -- Check if we have hint overlay elements inside the overlay
    local js = "document.querySelectorAll('#luakit_select_overlay .hint_overlay').length"
    w.view:eval_js(js, { callback = test.continue })
    local hint_count = test.wait()
    assert.is_equal(3, hint_count, "Expected 3 hint overlays, but got " .. tostring(hint_count))
    w:set_mode()
end

T.test_follow_and_scroll_after_history_back = function ()
    local w = assert(select(2, next(window.bywidget)))
    ensure_initial_page(w)

    local initial_uri = test.http_server("127.0.0.1") .. "test_follow.html"
    local cross_domain_uri = test.http_server("localhost") .. "test_follow.html"

    if w.view.uri ~= initial_uri then
        w.view.uri = initial_uri
        test.wait_for_view(w.view)
    end
    assert.is_equal(initial_uri, w.view.uri)

    -- Navigate cross-domain to another domain (localhost)
    w.view.uri = cross_domain_uri
    test.wait_for_view(w.view)
    assert.is_equal(cross_domain_uri, w.view.uri)

    -- Go back in history across domains (simulating Ctrl-o)
    w.view:go_back(1)
    test.delay(500)
    assert.is_equal(initial_uri, w.view.uri)
    assert.is_false(w.view.is_loading, "Webview should not be in loading state after history back")

    -- Test follow mode via key binding (f) after cross-domain history back navigation
    w:hit({}, "f")
    test.wait_for_idle()
    test.delay(300)

    assert.is_equal("follow", w.mode and w.mode.name)

    w.view:eval_js("!!document.getElementById('luakit_select_overlay')", { callback = test.continue })
    local overlay_exists = test.wait()
    assert.is_true(overlay_exists, "overlay element not found in DOM after history back!")

    local js = "document.querySelectorAll('#luakit_select_overlay .hint_overlay').length"
    w.view:eval_js(js, { callback = test.continue })
    local hint_count = test.wait()
    assert.is_equal(3, hint_count, "Expected 3 hint overlays after history back, got " .. tostring(hint_count))
    w:set_mode()

    -- Test scrolling via key binding (j) after cross-domain history back
    w:hit({}, "j")
    test.delay(100)
    w.view:eval_js("1 + 1", { callback = function (res, err) test.continue(res, err) end })
    local res, err = test.wait()
    assert.is_nil(err)
    assert.is_equal(2, res)
end

T.test_follow_link_cross_domain_and_history_back = function ()
    local w = assert(select(2, next(window.bywidget)))
    ensure_initial_page(w)

    local initial_uri = test.http_server("127.0.0.1") .. "test_follow.html"
    local cross_domain_uri = test.http_server("localhost") .. "test_follow.html"

    if w.view.uri ~= initial_uri then
        w.view.uri = initial_uri
        test.wait_for_view(w.view)
    end
    assert.is_equal(initial_uri, w.view.uri)

    -- Point first link to cross-domain destination
    local setup_js = "document.getElementById('link1').href = '" .. cross_domain_uri .. "';"
    w.view:eval_js(setup_js, { callback = function (res, err) test.continue(res, err) end })
    test.wait()

    -- Trigger follow mode and click the cross-domain link
    w:hit({}, "f")
    test.wait_for_idle()
    test.delay(300)
    assert.is_equal("follow", w.mode and w.mode.name)

    -- Press 1 then Return to follow the first link
    w:hit({}, "1")
    test.delay(100)
    w:hit({}, "Return")
    test.wait_for_view(w.view)
    assert.is_equal(cross_domain_uri, w.view.uri)

    -- Go back in history across domains
    w.view:go_back(1)
    test.delay(500)
    assert.is_equal(initial_uri, w.view.uri)
    assert.is_false(w.view.is_loading, "Webview should not be in loading state after follow link and back")

    -- Verify follow mode still works on the restored page
    w:hit({}, "f")
    test.wait_for_idle()
    test.delay(300)
    assert.is_equal("follow", w.mode and w.mode.name)

    local js = "document.querySelectorAll('#luakit_select_overlay .hint_overlay').length"
    w.view:eval_js(js, { callback = test.continue })
    local hint_count = test.wait()
    assert.is_equal(3, hint_count, "Expected 3 hint overlays on restored page, got " .. tostring(hint_count))
    w:set_mode()
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
