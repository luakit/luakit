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

local function wait_for_view(v)
    test.wait_for_view(v)
end

T.test_image_css = function ()
    local image_uri = test.http_server() .. "image_css/image.png"
    local page_uri = test.http_server() .. "image_css/default.html"
    local image_ss = image_css.stylesheet

    -- Load HTML page: stylesheet must be inactive
    view.uri = page_uri
    wait_for_view(view)
    assert.is_false(view.stylesheets[image_ss])

    -- Load image page: stylesheet must be active
    view.uri = image_uri
    wait_for_view(view)
    assert.is_true(view.stylesheets[image_ss])

    view:go_back(1)
    test.delay(200)
    assert.is_false(view.stylesheets[image_ss])

    view:go_forward(1)
    test.delay(200)
    assert.is_true(view.stylesheets[image_ss])

    view:go_back(1)
    test.delay(200)
    assert.is_false(view.stylesheets[image_ss])
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
