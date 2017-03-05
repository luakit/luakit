require "lunit"
local lousy = require "lousy"

module("test_lib_lousy_uri", lunit.testcase, package.seeall)

function test_lousy_uri_properties()
    local keys = {
        parse_query = true,
        parse = true,
        copy = true,
    }
    for k in pairs(keys) do
        assert_function(lousy.uri[k], "Missing/invalid property: lousy.uri." .. k)
    end
    for k in pairs(lousy.uri) do
        assert_true(keys[k], "Extra property: lousy.uri." .. k)
    end
end

function test_lousy_uri_parse()
    local uri = "http://test-user:p4ssw0rd@example.com:777/some~path?a=b&foo=bar#frag"
    local uri_without_password = "http://test-user@example.com:777/some~path?a=b&foo=bar#frag"
    local parsed = lousy.uri.parse(uri)
    assert_not_equal(nil, parsed, "Failed parsing uri '" .. uri .. "'")

    local keys = {
        scheme = "string",
        user = "string",
        password = "string",
        host = "string",
        path = "string",
        fragment = "string",
        opts = "table",
        port = "number",
    }
    for k, v in pairs(parsed) do
        assert_not_equal(nil, keys[k], "Extra lousy.uri uri property: " .. k)
        assert_true(type(v) == keys[k], "Wrong type for lousy.uri uri property: " .. k)
    end

    assert_equal("http", parsed.scheme, "Parsed uri has wrong scheme")
    assert_equal("test-user", parsed.user, "Parsed uri has wrong user")
    assert_equal("p4ssw0rd", parsed.password, "Parsed uri has wrong password")
    assert_equal("example.com", parsed.host, "Parsed uri has wrong host")
    assert_equal("/some~path", parsed.path, "Parsed uri has wrong path")
    assert_equal("frag", parsed.fragment, "Parsed uri has wrong fragment")

    local mt = getmetatable(parsed)
    assert_table(mt)
    assert_function(mt.__tostring)
    assert_function(mt.__add)

    assert_equal(tostring(parsed), uri_without_password)

    local props = {
        scheme = "luakit",
        user = "baz",
        host = "random-domain.com",
        path = "/",
        fragment = "",
        port = 888,
    }
    local props_uri = "luakit://baz@random-domain.com:888/?a=b&foo=bar"
    assert_equal(tostring(parsed + props), props_uri)
    props_uri = "luakit://baz@random-domain.com:888/"
    assert_equal(tostring(parsed + props + {query = ""}), props_uri)
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
