--- Test binds APIs.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local assert = require "luassert"
local lousy = require "lousy"

local T = {}

T.test_binds_are_called = function ()
    local binds = {}
    local hit_count = 0
    local action = { func = function () hit_count = hit_count + 1 end }

    lousy.bind.add_bind(binds, "a", action)
    lousy.bind.add_bind(binds, "<Control-C>", action)
    lousy.bind.add_bind(binds, "<Control-a>", action)
    lousy.bind.add_bind(binds, "gg", action)
    lousy.bind.add_bind(binds, ":test", action)
    lousy.bind.add_bind(binds, ":test-short, :test-loooooooong", action)
    lousy.bind.add_bind(binds, ":", action)
    lousy.bind.add_bind(binds, "<Shift-Tab>", action)
    lousy.bind.add_bind(binds, "<Shift-Mouse1>", action)
    lousy.bind.add_bind(binds, "gT", action)
    lousy.bind.add_bind(binds, "-", action)
    lousy.bind.add_bind(binds, "<C-S-D>", action)
    assert.equal(12, #binds)

    lousy.bind.hit(nil, binds, {}, "a", {})
    assert.equal(1, hit_count)

    lousy.bind.hit(nil, binds, {"Control", "Shift"}, "C", {})
    assert.equal(2, hit_count)

    local args = { buffer = "", enable_buffer = true }
    local _, newbuf = lousy.bind.hit(nil, binds, {}, "g", args)
    args.buffer = newbuf
    _, newbuf = lousy.bind.hit(nil, binds, {}, "g", args)
    args.buffer = newbuf
    assert.equal(3, hit_count)
    assert.equal(nil, args.buffer)

    lousy.bind.match_cmd(nil, binds, "test", {})
    lousy.bind.match_cmd(nil, binds, "test-short", {})
    lousy.bind.match_cmd(nil, binds, "test-loooooooong", {})
    assert.equal(6, hit_count)

    lousy.bind.hit(nil, binds, {"Control"}, "a", {})
    assert.equal(7, hit_count)

    lousy.bind.hit(nil, binds, {"Shift"}, ":", {})
    assert.equal(8, hit_count)
    lousy.bind.hit(nil, binds, {}, ":", {})
    assert.equal(9, hit_count)

    lousy.bind.hit(nil, binds, {"Shift"}, "Tab", {})
    assert.equal(10, hit_count)

    lousy.bind.hit(nil, binds, {"Shift"}, 1, {})
    assert.equal(11, hit_count)

    lousy.bind.hit(nil, binds, {}, "T", { buffer = "g", enable_buffer = true })
    assert.equal(12, hit_count)

    lousy.bind.hit(nil, binds, {}, "-", {})
    assert.equal(13, hit_count)

    lousy.bind.hit(nil, binds, {"Control", "Shift"}, "d", {})
    assert.equal(14, hit_count)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
