require "lunit"
module("test_clib_soup", lunit.testcase, package.seeall)

function test_module()
    assert_table(soup)
end

function test_properties()
    -- accept_language accept_language_auto
    soup.accept_language_auto = true
    assert_equal(true, soup.accept_language_auto)
    assert_string(soup.accept_language)
    soup.accept_language = "en-au, en"
    assert_equal("en-au, en", soup.accept_language)
    assert_equal(false, soup.accept_language_auto)

    soup.idle_timeout = 60
    assert_equal(60, soup.idle_timeout)

    soup.max_conns = 10
    assert_equal(10, soup.max_conns)

    soup.max_conns_per_host = 10
    assert_equal(10, soup.max_conns_per_host)

    soup.proxy_uri = "http://localhost/"
    assert_equal("http://localhost/", soup.proxy_uri)
    soup.proxy_uri = nil

    -- System dependant
    --soup.ssl_ca_file = "/etc/certs/ca-certificates.crt"
    --assert_equal("/etc/certs/ca-certificates.crt", soup.ssl_ca_file)

    soup.ssl_strict = true
    assert_equal(true, soup.ssl_strict)

    soup.timeout = 10
    assert_equal(10, soup.timeout)
end

function test_add_cookies()
    assert_error(function () soup.add_cookies("error") end)
    assert_error(function () soup.add_cookies({"error"}) end)
    assert_error(function () soup.add_cookies({{}}) end)

    assert_pass(function ()
        soup.add_cookies({
            { domain = "google.com", path = "/", name = "test",
              value = "test", expires = 10, http_only = true, secure = true }
        })
    end)

    assert_pass(function ()
        soup.add_cookies({
            { domain = "google.com", path = "/", name = nil,
              value = "test", expires = 10, http_only = true, secure = true }
        })
        soup.add_cookies({
            { domain = "google.com", path = "/", name = "",
              value = nil, expires = 10, http_only = true, secure = true }
        })
        soup.add_cookies({
            { domain = "google.com", path = "/", name = "",
              value = "", expires = 10, http_only = true, secure = true }
        })
        soup.add_cookies({
            { domain = "google.com", path = "/", name = "test",
              value = "test", expires = 10, http_only = 1, secure = 1 }
        })
    end)

    assert_error(function ()
        soup.add_cookies({
            { domain = 10, path = "/", name = "test",
              value = "test", expires = 10, http_only = true, secure = true }
        })
    end)
    assert_error(function ()
        soup.add_cookies({
            { domain = "google.com", path = 10, name = "test",
              value = "test", expires = 10, http_only = true, secure = true }
        })
    end)
end
