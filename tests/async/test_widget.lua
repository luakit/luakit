--- Test widget library.
--
-- @copyright 2017 Aidan Holm

local assert = require "luassert"

local T = {}

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

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
