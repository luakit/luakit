--- Test widget library.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local assert = require "luassert"

local T = {}

T.test_widget_of_invalid_type_fails = function ()
    assert.has_error(function () widget{type="no_such_widget_type"} end)
    assert.has_error(function () widget{} end)
end

T.test_bin_widget_set_child = function ()
    local bin = widget{type="window"}
    local child1 = widget{type="entry"}
    local child2 = widget{type="label"}

    assert.is_nil(bin.child)
    bin.child = child1
    assert.is_equal(bin.child, child1)
    bin.child = child2
    assert.is_equal(bin.child, child2)
    bin.child = nil
    assert.is_nil(bin.child)
end

T.test_webview_widget_privacy = function ()
    local v = widget{type="webview"}
    assert.is_false(v.private)
    v = widget{type="webview", private=false}
    assert.is_false(v.private)
    v = widget{type="webview", private=true}
    assert.is_true(v.private)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
