--- Test gopher module.

local assert = require "luassert"
local gopher = require "gopher"
local T = {}

T.test_image_mime_type = function()
    local f = gopher.image_mime_type
    assert.is_equal("image/gif", f("gif"))
    assert.is_equal("image/jpeg", f("JPG"))
    assert.is_equal("image/svg+xml", f("svg"))
    assert.is_equal("application/octet-stream", f())
end

T.test_parse_url_simple = function()
    local url
    url = gopher.parse_url("gopher://example.com")
    assert.is_equal(url.host, "example.com")
    assert.is_equal(url.port, 70)
    assert.is_equal(url.gophertype, "1")
    assert.is_equal(url.selector, "")
    assert.is_nil(url.search)
    assert.is_nil(url.gopher_plus_string)
end

T.test_parse_url_complex = function()
    local url
    url = gopher.parse_url("gopher://example.com:80/0/file.txt%09please/search%09plus/command")
    assert.is_equal(url.host, "example.com")
    assert.is_equal(url.port, 80)
    assert.is_equal(url.gophertype, "0")
    assert.is_equal(url.selector, "/file.txt")
    assert.is_equal(url.search, "please/search")
    assert.is_equal(url.gopher_plus_string, "plus/command")
end

T.test_href_source_telnet = function()
    local entry = {
        scheme = "telnet",
        host = "example.com",
        port = 23,
        selector = "/"
    }
    assert.is_equal("telnet://example.com:23/", gopher.href_source(entry))
end

T.test_href_source_gopher_text_file = function()
    local entry = {
        scheme = "gopher",
        host = "example.com",
        port = 70,
        item_type = "0",
        selector = "/abc"
    }
    assert.is_equal("gopher://example.com:70/0/abc", gopher.href_source(entry))
end

T.test_href_source_https_text_file = function()
    local entry = {
        selector = "URL:https://example.com/abc?q=1"
    }
    assert.is_equal("https://example.com/abc?q=1", gopher.href_source(entry))
end

T.test_parse_gopher_line = function()
    local line = "0Sample Text\t/selector/part here\texample1.com\t80"
    local url = {
        host = "example.com",
        port = 70
    }
    local entry = gopher.parse_gopher_line(line, url)
    assert.is_equal(line, entry.line)
    assert.is_equal("0", entry.item_type)
    assert.is_equal("Sample Text", entry.display_string)
    assert.is_equal("/selector/part here", entry.selector)
    assert.is_equal("example1.com", entry.host)
    assert.is_equal("80", entry.port)
    assert.is_equal("gopher", entry.scheme)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
