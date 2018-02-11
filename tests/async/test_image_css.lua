--- Test image CSS.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local assert = require "luassert"
local test = require "tests.lib"
local lousy = require "lousy"

local T = {}

local window = widget{type="window"}
local view = widget{type="webview"}
window.child = view
window:show()

-- Stub out webview module
package.loaded.webview = lousy.signal.setup({}, true)
local image_css = require("image_css")
package.loaded.webview.emit_signal("init", view)

local view_wait_for_status = function (v, status)
    repeat
        local _, s, uri, err = test.wait_for_signal(v, "load-status", 1000)
        if s == "failed" then
            local fmt = "tests.wait_for_view() failed loading '%s': %s"
            local msg = fmt:format(uri, err)
            assert(false, msg)
        end
    until s == status
end

T.test_image_css = function ()
    local image_uri = test.http_server() .. "image_css/image.png"
    local page_uri = test.http_server() .. "image_css/default.html"
    local image_ss = image_css.stylesheet

    -- Load HTML page: stylesheet must be inactive
    view.uri = page_uri
    view_wait_for_status(view, "committed")
    assert.is_false(view.stylesheets[image_ss])

    -- Load image page: stylesheet must be active
    view.uri = image_uri
    view_wait_for_status(view, "committed")
    assert.is_true(view.stylesheets[image_ss])

    view:go_back(1)
    view_wait_for_status(view, "committed")
    assert.is_false(view.stylesheets[image_ss])

    view:go_forward(1)
    view_wait_for_status(view, "committed")
    assert.is_true(view.stylesheets[image_ss])

    view:go_back(1)
    view_wait_for_status(view, "committed")
    assert.is_false(view.stylesheets[image_ss])
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
