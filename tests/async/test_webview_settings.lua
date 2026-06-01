--- Test that webview settings are applied before the first HTTP request.
--
-- Verifies that settings.get_setting_for_view_at_uri is called via the
-- navigation-request signal handler before WebKit dispatches any network
-- request, so the correct WebKitSettings are in place from the very first
-- connection.
--
-- @copyright 2026 c0dev0id

local test = require "tests.lib"
local assert = require "luassert"

uris = { "about:blank" }
require "config.rc"

local settings = require "settings"
local webview = require "webview"

local T = {}

T.test_user_agent_applied_on_first_navigation = function ()
    test.wait_for_idle()

    local orig = settings.webview.user_agent
    settings.webview.user_agent = "TestAgent/1.0"

    local view = webview.new({})

    -- This handler runs after webview.lua's navigation-request handler (FIFO
    -- ordering), so set_all_for_uri has already applied the new user_agent.
    local captured_ua
    view:add_signal("navigation-request", function (v)
        captured_ua = v.user_agent
    end)

    view.uri = test.http_server() .. "hello_world.html"
    test.wait_for_view(view)

    settings.webview.user_agent = orig
    assert.equal("TestAgent/1.0", captured_ua)
end

T.test_enable_javascript_applied_on_first_navigation = function ()
    test.wait_for_idle()

    local orig = settings.webview.enable_javascript
    settings.webview.enable_javascript = false

    local view = webview.new({})

    local captured_js
    view:add_signal("navigation-request", function (v)
        captured_js = v.enable_javascript
    end)

    view.uri = test.http_server() .. "hello_world.html"
    test.wait_for_view(view)

    settings.webview.enable_javascript = orig
    assert.is_false(captured_js)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
