--- Test history module.
--
-- @copyright 2026

local assert = require "luassert"
local test = require "tests.lib"

uris = {"about:blank"}
require "config.rc"

local history = require "history"

local T = {}

T.test_history_logging = function ()
    test.wait_for_idle()

    -- Ensure history is initialized
    history.init()

    -- Clear history database
    history.db:exec("DELETE FROM history")

    -- Add history entry
    history.add("http://example.com/page1", "Page One")
    test.wait_for_idle()

    -- Check if entry was inserted
    local rows = history.db:exec("SELECT * FROM history WHERE uri = ?", { "http://example.com/page1" })
    assert.equal(1, #rows)
    assert.equal("Page One", rows[1].title)
    assert.equal(1, rows[1].visits)

    -- Visit the same URI again
    history.add("http://example.com/page1", "Page One Updated")
    test.wait_for_idle()

    -- Check if visits count was updated
    rows = history.db:exec("SELECT * FROM history WHERE uri = ?", { "http://example.com/page1" })
    assert.equal(1, #rows)
    assert.equal("Page One Updated", rows[1].title)
    assert.equal(2, rows[1].visits)

    -- Add another URI
    history.add("http://example.com/page2", "Page Two")
    test.wait_for_idle()

    -- Check total entries
    rows = history.db:exec("SELECT * FROM history ORDER BY last_visit ASC")
    assert.equal(2, #rows)
    assert.equal("http://example.com/page1", rows[1].uri)
    assert.equal("http://example.com/page2", rows[2].uri)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
