--- Test built-in commands.
--
-- @copyright 2026

local assert = require "luassert"
local test = require "tests.lib"
local settings = require "settings"

uris = {"about:blank"}
require "config.rc"

local window = require "window"
local w = assert(select(2, next(window.bywidget)))

local T = {}

T.test_command_open = function ()
    test.wait_for_idle()

    -- Test :open command
    local target = test.http_server() .. "test_follow.html"
    w:run_cmd(":open " .. target)
    test.wait_for_view(w.view)
    assert.equal(target, w.view.uri)
end

T.test_command_tabopen_and_close = function ()
    test.wait_for_idle()
    local initial_tab_count = #w.tabs

    -- Test :tabopen command
    w:run_cmd(":tabopen about:blank")
    test.wait_for_idle()
    assert.equal(initial_tab_count + 1, #w.tabs)
    assert.equal(2, w.tabs:current())

    -- Test :close command
    w:run_cmd(":close")
    test.wait_for_idle()
    assert.equal(initial_tab_count, #w.tabs)
    assert.equal(1, w.tabs:current())
end

T.test_command_set = function ()
    test.wait_for_idle()
    local old_zoom = settings.get_setting("webview.zoom_level")

    -- Test :set zoom level
    w:run_cmd(":set webview.zoom_level 150")
    test.wait_for_idle()
    assert.equal(150, settings.get_setting("webview.zoom_level"))

    -- Restore old setting
    settings.set_setting("webview.zoom_level", old_zoom)
end

T.test_command_seton = function ()
    test.wait_for_idle()
    local old_zoom = settings.get_setting("webview.zoom_level", { domain = "example.com" })

    -- Test :seton for a domain
    w:run_cmd(":seton example.com webview.zoom_level 250")
    test.wait_for_idle()
    assert.equal(250, settings.get_setting("webview.zoom_level", { domain = "example.com" }))

    -- Restore old setting
    settings.set_setting("webview.zoom_level", old_zoom, { domain = "example.com" })
end

T.test_command_javascript = function ()
    test.wait_for_idle()
    w.view.uri = "about:blank"
    test.wait_for_view(w.view)

    -- Test :javascript command
    w:run_cmd(":js window.luakit_test_var = 12345")
    test.delay(100)

    -- Read back the variable using eval_js
    w.view:eval_js("window.luakit_test_var", { callback = function (res) test.continue(res) end })
    local val = test.wait()
    assert.equal(12345, val)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
