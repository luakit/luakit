--- Test downloads module.
--
-- @copyright 2026

local assert = require "luassert"
local test = require "tests.lib"

uris = {"about:blank"}
require "config.rc"

local downloads = require "downloads"

local T = {}

T.test_download_file = function ()
    test.wait_for_idle()

    local dest = "/tmp/download_test.html"
    os.remove(dest)

    local d = downloads.add("data:text/html,Hello%20World", { filename = dest })

    -- Wait for the download to finish if not already completed
    d:add_signal("error", function (_, err)
        assert(false, "Download failed: " .. tostring(err))
    end)

    if d.status ~= "finished" then
        d:add_signal("finished", function ()
            test.continue()
        end)
        test.wait(5000)
    end

    test.delay(50)
    local f = io.open(dest, "r")
    assert.is_not_nil(f, "Downloaded file not found")
    local content = f:read("*a")
    f:close()
    assert.is_true(#content > 0, "Downloaded file is empty")

    -- Clean up
    os.remove(dest)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
