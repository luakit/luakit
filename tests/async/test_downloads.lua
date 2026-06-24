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

    local dest = luakit.data_dir .. "/download_test.html"
    os.remove(dest)

    -- Create download object
    local d = download{uri = "luakit-test://test_follow.html"}

    -- Wait for the download to finish
    d:add_signal("finished", function ()
        test.continue()
    end)

    d:add_signal("error", function (_, err)
        assert(false, "Download failed: " .. tostring(err))
    end)

    -- Start the download with specified destination
    downloads.add(d, { filename = dest })

    -- Wait for finished signal
    test.wait(5000)

    -- Verify file exists and is not empty
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
