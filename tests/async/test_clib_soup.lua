--- Test luakit soup functionality.
--
-- @copyright 2017 Aidan Holm

local assert = require "luassert"

local T = {}

T.test_soup = function ()
    assert.are.same(soup.parse_uri(""), nil)
    assert.are.same(soup.parse_uri("about:blank"), {
        scheme = "about",
        path = "blank",
    })
    assert.are.same(soup.parse_uri("example.com"), {
        scheme = "http",
        host = "example.com",
        path = "/",
        port = 80,
    })
    assert.are.same(soup.parse_uri("https://www.example.com:900"), {
        scheme = "https",
        host = "www.example.com",
        path = "/",
        port = 900,
    })
    assert.are.same(soup.parse_uri("luakit://page"), {
        scheme = "luakit",
        host = "page",
    })
    assert.are.same(soup.parse_uri("luakit://page/foo"), {
        scheme = "luakit",
        host = "page",
        path = "/foo",
    })
    assert.are.same(soup.parse_uri("view-source:luakit://page/foo"), {
        scheme = "view-source",
        path = "luakit://page/foo",
    })
end

T.test_set_proxy_uri = function ()
    soup.proxy_uri = "default"
    assert.equal(soup.proxy_uri, "default")
    soup.proxy_uri = "no_proxy"
    assert.equal(soup.proxy_uri, "no_proxy")
    soup.proxy_uri = "no_proxy"
    assert.equal(soup.proxy_uri, "no_proxy")
    soup.proxy_uri = nil
    assert.equal(soup.proxy_uri, "default")
    assert.has_error(function () soup.proxy_uri = true end)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
