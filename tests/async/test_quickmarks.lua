--- Test quickmarks module.
--
-- @copyright 2026

local assert = require "luassert"
local test = require "tests.lib"

uris = {"about:blank"}
require "config.rc"

local quickmarks = require "quickmarks"

local T = {}

T.test_quickmarks_ops = function ()
    test.wait_for_idle()

    -- We'll use a temporary file path for testing quickmarks file operations
    local temp_file = luakit.data_dir .. "/quickmarks_test"
    
    -- Ensure clean state
    quickmarks.delall(false)

    -- Test token validation
    assert.has_error(function () quickmarks.set("longtoken", "http://example.com") end)
    assert.has_error(function () quickmarks.set("!", "http://example.com") end)

    -- Add some quickmarks
    quickmarks.set("g", "http://google.com", false, false)
    quickmarks.set("l", "http://luakit.org, http://luakit.github.io", false, false)

    -- Retrieve quickmarks
    local g_mark = quickmarks.get("g", false)
    assert.is_table(g_mark)
    assert.equal("http://google.com", g_mark[1])

    local l_mark = quickmarks.get("l", false)
    assert.is_table(l_mark)
    assert.equal("http://luakit.org", l_mark[1])
    assert.equal("http://luakit.github.io", l_mark[2])

    -- Get tokens list
    local tokens = quickmarks.get_tokens()
    table.sort(tokens)
    assert.equal(2, #tokens)
    assert.equal("g", tokens[1])
    assert.equal("l", tokens[2])

    -- Save to temp file
    quickmarks.save(temp_file)

    -- Clear memory state
    quickmarks.delall(false)
    assert.is_nil(quickmarks.get("g", false))

    -- Load from temp file
    quickmarks.load(temp_file)
    assert.equal("http://google.com", quickmarks.get("g", false)[1])

    -- Delete a single quickmark
    quickmarks.del("g", false, false)
    assert.is_nil(quickmarks.get("g", false))

    -- Clean up temporary file
    os.remove(temp_file)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
