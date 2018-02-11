--- Test page scrolling.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local T = {}
local test = require "tests.lib"
local assert = require "luassert"

uris = { test.http_server() .. "scroll.html" }
require "config.rc"

local window = require "window"
local w = assert(select(2, next(window.bywidget)))

T.test_scrolling_works = function ()
    test.wait_for_view(w.view)

    -- Fetch height of document body
    w.view:eval_js("document.body.getClientRects()[0].height", { callback = test.continue })
    local doc_height = test.wait()

    local get_scroll_y = function ()
        w.view:eval_js("window.scrollY", { callback = test.continue })
        return test.wait()
    end

    assert.is_equal(0, get_scroll_y(),
        "Scroll position should start at top.")

    w:scroll{ yrel = 100 }
    assert.is_equal(100, get_scroll_y(),
        "Relative scrolling failed")

    w:scroll{ yrel = -100 }
    assert.is_equal(0, get_scroll_y(),
        "Relative scrolling failed")

    w:scroll{ yrel = -100 }
    assert.is_equal(0, get_scroll_y(),
        "Scrolling didn't stop when already at end")

    w:scroll{ yrel = 100 }
    assert.is_equal(100, get_scroll_y(),
        "Relative scrolling after scrolling against scroll-end failed")


    w:scroll{ y = 0 }
    assert.is_equal(0, get_scroll_y(),
        "Scrolling to top failed")

    w:scroll{ y = -1 }
    -- Scrolling to bottom requires a JS roundtrip to get document height
    -- first, so wait until that's finished before continuing...
    test.wait_until(function () return w.view.scroll.y > 0 end)
    assert.is_equal(doc_height - w.view.height, get_scroll_y(),
        "Scrolling to bottom failed")


    w:scroll{ ypct = 0 }
    test.wait_until(function () return w.view.scroll.y == 0 end)

    w:scroll{ ypct = 100 }
    test.wait_until(function () return w.view.scroll.y > 0 end)
    assert.is_equal(doc_height - w.view.height, get_scroll_y(),
        "Scrolling to 100% failed")
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
