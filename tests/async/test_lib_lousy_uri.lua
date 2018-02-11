--- Test lousy.uri functionality.
--
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

local assert = require "luassert"
local lousy = require "lousy"

local T = {}

T.test_lousy_uri_properties = function ()
    local keys = {
        is_uri = true,
        split = true,
        parse_query = true,
        parse = true,
        copy = true,
        domains_from_uri = true,
    }
    for k in pairs(keys) do
        assert.is_function(lousy.uri[k], "Missing/invalid property: lousy.uri." .. k)
    end
    for k in pairs(lousy.uri) do
        assert.is_true(keys[k], "Extra property: lousy.uri." .. k)
    end
end

T.test_lousy_uri_parse_is_uri = function()
    -- File URIs and /etc/hosts are system-dependant so they won't be tested
    local is_uri = lousy.uri.is_uri
    assert.is_true(is_uri("localhost"))
    assert.is_true(is_uri("localhost:8080"))
    assert.is_true(is_uri("about:blank"))
    assert.is_true(is_uri("javascript:alert('message')"))
    assert.is_false(is_uri(".example.com"))
    assert.is_true(is_uri("https://github.com/luakit/luakit"))
    assert.is_true(is_uri("http://localhost:8000/tests/"))
    assert.is_true(is_uri("luakit.github.io"))
    assert.is_true(is_uri("http://www.shareprice.co.uk/TW."))
    assert.is_false(is_uri("etc."))
end

T.test_lousy_uri_parse_split = function()
    local s = [[github.com Monsters,   Inc. (http://i.imgur.com/BxXBmVL.gif),
                I love localhost	ice cream. ]]
    local t = {"github.com", "Monsters, Inc.", "http://i.imgur.com/BxXBmVL.gif",
               "I love", "localhost", "ice cream."}
    assert.are.same(t, lousy.uri.split(s))

    local js = "javascript:alert('foo'); confirm('bar')"
    assert.are.same({js}, lousy.uri.split(js))
end

T.test_lousy_uri_parse = function ()
    local uri = "http://test-user:p4ssw0rd@example.com:777/some~path?a=b&foo=bar#frag"
    local uri_without_password = "http://test-user@example.com:777/some~path?a=b&foo=bar#frag"
    local parsed = lousy.uri.parse(uri)
    assert.is_not_equal(nil, parsed, "Failed parsing uri '" .. uri .. "'")

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
        assert.is_not_equal(nil, keys[k], "Extra lousy.uri uri property: " .. k)
        assert.is_true(type(v) == keys[k], "Wrong type for lousy.uri uri property: " .. k)
    end

    assert.is_equal("http", parsed.scheme, "Parsed uri has wrong scheme")
    assert.is_equal("test-user", parsed.user, "Parsed uri has wrong user")
    assert.is_equal("p4ssw0rd", parsed.password, "Parsed uri has wrong password")
    assert.is_equal("example.com", parsed.host, "Parsed uri has wrong host")
    assert.is_equal("/some~path", parsed.path, "Parsed uri has wrong path")
    assert.is_equal("frag", parsed.fragment, "Parsed uri has wrong fragment")

    local mt = getmetatable(parsed)
    assert.is_table(mt)
    assert.is_function(mt.__tostring)
    assert.is_function(mt.__add)

    assert.is_equal(tostring(parsed), uri_without_password)

    local props = {
        scheme = "luakit",
        user = "baz",
        host = "random-domain.com",
        path = "/",
        fragment = "",
        port = 888,
    }
    local props_uri = "luakit://baz@random-domain.com:888/?a=b&foo=bar"
    assert.is_equal(tostring(parsed + props), props_uri)
    props_uri = "luakit://baz@random-domain.com:888/"
    assert.is_equal(tostring(parsed + props + {query = ""}), props_uri)
end

T.test_lousy_uri_domains_from_uri = function ()
    local f = lousy.uri.domains_from_uri
    assert.are.same({".example.com", "example.com", ".com"}, f("example.com"))
    assert.are.same({".example.com", "example.com", ".com"}, f("www.example.com"))
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
