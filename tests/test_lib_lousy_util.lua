require "lunit"
local lousy = require "lousy"

module("test_lib_lousy_util", lunit.testcase, package.seeall)

function test_lousy_util_table_join()
    local a = { 1, 2, "a", "b" }
    local b = { "foo", "bar", 777 }
    local c = { "baz" }
    local sum = { 1, 2, "a", "b", "foo", "bar", 777, "baz" }
    assert_true(lousy.util.table.isclone(sum, lousy.util.table.join(a, b, c)))
end

function test_lousy_util_table_isclone()
    local a = { 1, 2, 3, x="foo", y="bar" }
    local b = { 1, 2, false, x="foo", y="bar" }

    assert_false(lousy.util.table.isclone(a, b))
    b[3] = 3
    assert_true(lousy.util.table.isclone(a, b))
    assert_true(lousy.util.table.isclone(a, a))
    a.y = true
    assert_false(lousy.util.table.isclone(a, b))
end

function test_lousy_util_table_reverse()
    local a = { "backwards", "am", "I", x="foo", y="bar" }
    local b = { "I", "am", "backwards", x="foo", y="bar" }
    a = lousy.util.table.reverse(a)
    assert_true(lousy.util.table.isclone(a, b))
    a = lousy.util.table.reverse(a)
    b = lousy.util.table.reverse(b)
    assert_true(lousy.util.table.isclone(a, b))
end

function test_lousy_util_table_toarray()
    local a = { "I", "IV", x="foo","IX", "XVI", y="bar" }
    local b = { "I", "IV", "IX", "XVI" }
    a = lousy.util.table.toarray(a)
    assert_true(lousy.util.table.isclone(a, b))
end

function test_lousy_util_table_copy_clone()
    local mt = {}
    local a = { "I", "IV", x="foo","IX", "XVI", y="bar" }
    setmetatable(a, mt)

    local c = lousy.util.table.copy(a)
    assert_not_equal(a, c)
    assert_true(lousy.util.table.isclone(a, c))
    assert_equal(mt, getmetatable(c))

    local c = lousy.util.table.clone(a)
    assert_not_equal(a, c)
    assert_true(lousy.util.table.isclone(a, c))
    assert_equal(nil, getmetatable(c), mt)
end

function test_lousy_util_table_filter_array()
    local a = { "I", "IV", x="foo","IX", "XVI", y="bar" }

    -- Non-array items are dropped
    local b = lousy.util.table.filter_array(a, function () return true end)
    assert_true(lousy.util.table.isclone(b, { "I", "IV", "IX", "XVI" }))

    local c = lousy.util.table.filter_array(a, function (i, _) return i % 2 == 0 end)
    assert_true(lousy.util.table.isclone(c, { "IV", "XVI" }))
    local d = lousy.util.table.filter_array(a, function (_, v) return v:len() == 2 end)
    assert_true(lousy.util.table.isclone(d, { "IV", "IX" }))
end
