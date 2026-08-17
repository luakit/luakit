--- Test adblock module.
--
-- @copyright 2026

local assert = require "luassert"
local test = require "tests.lib"
local lfs = require "lfs"

uris = {"about:blank"}
require "config.rc"

local window = require "window"
local w = assert(select(2, next(window.bywidget)))
local adblock = require "adblock"

-- Prepare custom filter rules
local adblock_dir = luakit.data_dir .. "/adblock/"
local mode = lfs.attributes(adblock_dir, "mode")
if not mode then
    lfs.mkdir(adblock_dir)
end

local f = io.open(adblock_dir .. "testlist.txt", "w")
assert(f, "Failed to write adblock test list")
f:write("||adserver.com\n")
f:write("@@||adserver.com/whitelist\n")
f:close()

-- Reload adblock to load the new rules
adblock.load(true)

local T = {}

T.test_adblock_blocking = function ()
    test.wait_for_idle()
    adblock.clear_page_whitelist()
    adblock.enabled = true
    test.delay(500) -- Allow rules update to propagate to web process

    -- Navigate to blocked address
    w.view.uri = "luakit-test://adserver.com/ad.html"
    test.wait_for_view(w.view)

    -- Check if redirected to adblock-blocked page
    assert.is_match("^adblock%-blocked:", w.view.uri)
end

T.test_adblock_whitelisting = function ()
    test.wait_for_idle()
    adblock.clear_page_whitelist()
    adblock.enabled = true
    test.delay(500)

    -- Whitelist adserver.com
    adblock.whitelist_domain_access("adserver.com")
    test.delay(500)

    -- Navigate to whitelisted address
    w.view.uri = "luakit-test://adserver.com/whitelist.html"
    test.wait_for_view(w.view)
    test.wait_until(function () return w.view.uri == "luakit-test://adserver.com/whitelist.html" end)

    -- Check that it was NOT blocked (it remains on the target URI)
    assert.equal("luakit-test://adserver.com/whitelist.html", w.view.uri)
end

T.test_adblock_disabled = function ()
    test.wait_for_idle()
    adblock.clear_page_whitelist()
    adblock.enabled = false
    test.delay(500)

    -- Navigate to blocked address with adblock disabled
    w.view.uri = "luakit-test://adserver.com/ad.html"
    test.wait_for_view(w.view)
    test.wait_until(function () return w.view.uri == "luakit-test://adserver.com/ad.html" end)

    -- Check that it was NOT blocked (it remains on the target URI)
    assert.equal("luakit-test://adserver.com/ad.html", w.view.uri)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
