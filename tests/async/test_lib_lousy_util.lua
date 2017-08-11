--- Test lousy.util functionality.
--
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

local assert = require "luassert"
local lousy = require "lousy"

local T = {}

T.test_lousy_util_table_join = function ()
    local a = { 1, 2, "a", "b" }
    local b = { "foo", "bar", 777 }
    local c = { "baz" }
    local sum = { 1, 2, "a", "b", "foo", "bar", 777, "baz" }
    assert.is_true(lousy.util.table.isclone(sum, lousy.util.table.join(a, b, c)))

    a = { a = 1, b = 1, c = 1 }
    b = { b = 2, c = 2 }
    c = { c = 3 }
    sum = { a = 1, b = 2, c = 3 }
    assert.is_true(lousy.util.table.isclone(sum, lousy.util.table.join(a, b, c)))
end

T.test_lousy_util_table_isclone = function ()
    local a = { 1, 2, 3, x="foo", y="bar" }
    local b = { 1, 2, false, x="foo", y="bar" }

    assert.is_false(lousy.util.table.isclone(a, b))
    b[3] = 3
    assert.is_true(lousy.util.table.isclone(a, b))
    assert.is_true(lousy.util.table.isclone(a, a))
    a.y = true
    assert.is_false(lousy.util.table.isclone(a, b))
end

T.test_lousy_util_table_reverse = function ()
    local a = { "backwards", "am", "I", x="foo", y="bar" }
    local b = { "I", "am", "backwards", x="foo", y="bar" }
    a = lousy.util.table.reverse(a)
    assert.is_true(lousy.util.table.isclone(a, b))
    a = lousy.util.table.reverse(a)
    b = lousy.util.table.reverse(b)
    assert.is_true(lousy.util.table.isclone(a, b))
end

T.test_lousy_util_table_toarray = function ()
    local a = { "I", "IV", x="foo","IX", "XVI", y="bar" }
    local b = { "I", "IV", "IX", "XVI" }
    a = lousy.util.table.toarray(a)
    assert.is_true(lousy.util.table.isclone(a, b))
end

T.test_lousy_util_table_copy_clone = function ()
    local mt = {}
    local a = { "I", "IV", x="foo","IX", "XVI", y="bar" }
    setmetatable(a, mt)

    local c = lousy.util.table.copy(a)
    assert.is_not_equal(a, c)
    assert.is_true(lousy.util.table.isclone(a, c))
    assert.is_equal(mt, getmetatable(c))

    c = lousy.util.table.clone(a)
    assert.is_not_equal(a, c)
    assert.is_true(lousy.util.table.isclone(a, c))
    assert.is_equal(nil, getmetatable(c), mt)
end

T.test_lousy_util_table_filter_array = function ()
    local a = { "I", "IV", x="foo","IX", "XVI", y="bar" }

    -- Non-array items are dropped
    local b = lousy.util.table.filter_array(a, function () return true end)
    assert.is_true(lousy.util.table.isclone(b, { "I", "IV", "IX", "XVI" }))

    local c = lousy.util.table.filter_array(a, function (i, _) return i % 2 == 0 end)
    assert.is_true(lousy.util.table.isclone(c, { "IV", "XVI" }))
    local d = lousy.util.table.filter_array(a, function (_, v) return v:len() == 2 end)
    assert.is_true(lousy.util.table.isclone(d, { "IV", "IX" }))
end

T.test_lousy_util_lua_escape = function ()
    local magic = "^$()%.[]*+-?)"

    for i=1,#magic do
        local ch = magic:sub(i,i)
        assert.equal(" %" .. ch .. " ", lousy.util.lua_escape(" " .. ch .. " "))
    end
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
