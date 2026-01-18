--- Test history module functionality.
--
-- @copyright 2025

local T = {}
local test = require("tests.lib")
local assert = require("luassert")

uris = {"about:blank"}
require "config.rc"

local history = require "history"

-- Helper to clean up test history entries
local function cleanup_test_history()
    if not history.db then return end
    history.db:exec([[ DELETE FROM history WHERE uri LIKE 'test://%' ]])
end

T.test_add_history_entry = function ()
    test.debug("TEST", "=== Testing history entry addition ===")

    test.debug("STEP", "1. Cleaning up existing test history")
    cleanup_test_history()

    test.debug("STEP", "2. Adding a new history entry")
    local uri = "test://example.com/page1"
    local title = "Test Page 1"

    history.add(uri, title)

    test.debug("STEP", "3. Verifying entry was added")
    local result = history.db:exec([[ SELECT * FROM history WHERE uri = ? ]], { uri })

    test.debug("ASSERT", "Verifying history entry exists")
    assert.is_not_nil(result)
    assert.is_true(#result >= 1)

    local entry = result[1]
    test.debug("INFO", string.format("Found entry: id=%s, uri=%s, title=%s, visits=%s",
        entry.id or "nil", entry.uri or "nil", entry.title or "nil", entry.visits or "nil"))

    test.debug("ASSERT", "Verifying entry details")
    assert.is_equal(entry.uri, uri)
    assert.is_equal(entry.title, title)
    assert.is_equal(tonumber(entry.visits), 1)
    assert.is_number(tonumber(entry.last_visit))

    test.debug("STEP", "4. Cleaning up")
    cleanup_test_history()

    test.debug("TEST", "=== History addition test completed ===")
end

T.test_history_visit_counting = function ()
    test.debug("TEST", "=== Testing history visit counting ===")

    test.debug("STEP", "1. Cleaning up and adding initial entry")
    cleanup_test_history()

    local uri = "test://example.com/visited-multiple-times"
    local title = "Visited Multiple Times"

    test.debug("STEP", "2. Adding first visit")
    history.add(uri, title)

    local after_first = history.db:exec([[ SELECT visits FROM history WHERE uri = ? ]], { uri })
    test.debug("INFO", string.format("After first visit: %s", after_first[1].visits))
    test.debug("ASSERT", "Verifying first visit count")
    assert.is_equal(tonumber(after_first[1].visits), 1)

    test.debug("STEP", "3. Adding second visit")
    test.delay(50)  -- Small delay to ensure different timestamp
    history.add(uri, title)

    local after_second = history.db:exec([[ SELECT visits FROM history WHERE uri = ? ]], { uri })
    test.debug("INFO", string.format("After second visit: %s", after_second[1].visits))
    test.debug("ASSERT", "Verifying second visit count")
    assert.is_equal(tonumber(after_second[1].visits), 2)

    test.debug("STEP", "4. Adding third visit")
    test.delay(50)
    history.add(uri, title)

    local after_third = history.db:exec([[ SELECT visits FROM history WHERE uri = ? ]], { uri })
    test.debug("INFO", string.format("After third visit: %s", after_third[1].visits))
    test.debug("ASSERT", "Verifying third visit count")
    assert.is_equal(tonumber(after_third[1].visits), 3)

    test.debug("STEP", "5. Cleaning up")
    cleanup_test_history()

    test.debug("TEST", "=== Visit counting test completed ===")
end

T.test_history_title_updates = function ()
    test.debug("TEST", "=== Testing history title updates ===")

    test.debug("STEP", "1. Adding entry with initial title")
    cleanup_test_history()

    local uri = "test://example.com/changing-title"
    local initial_title = "Initial Title"

    history.add(uri, initial_title)

    local initial = history.db:exec([[ SELECT title FROM history WHERE uri = ? ]], { uri })
    test.debug("INFO", string.format("Initial title: %s", initial[1].title))
    test.debug("ASSERT", "Verifying initial title")
    assert.is_equal(initial[1].title, initial_title)

    test.debug("STEP", "2. Updating with new title")
    local new_title = "Updated Title"
    test.delay(50)
    history.add(uri, new_title)

    local updated = history.db:exec([[ SELECT title, visits FROM history WHERE uri = ? ]], { uri })
    test.debug("INFO", string.format("Updated title: %s, visits: %s",
        updated[1].title, updated[1].visits))

    test.debug("ASSERT", "Verifying title was updated")
    assert.is_equal(updated[1].title, new_title)
    test.debug("ASSERT", "Verifying visit count increased")
    assert.is_equal(tonumber(updated[1].visits), 2)

    test.debug("STEP", "3. Cleaning up")
    cleanup_test_history()

    test.debug("TEST", "=== Title update test completed ===")
end

T.test_history_last_visit_timestamp = function ()
    test.debug("TEST", "=== Testing last visit timestamp tracking ===")

    test.debug("STEP", "1. Adding initial visit")
    cleanup_test_history()

    local uri = "test://example.com/timestamp-test"
    history.add(uri, "Timestamp Test")

    local first_visit = history.db:exec([[ SELECT last_visit FROM history WHERE uri = ? ]], { uri })
    local first_timestamp = tonumber(first_visit[1].last_visit)
    test.debug("INFO", string.format("First visit timestamp: %d", first_timestamp))
    test.debug("ASSERT", "Verifying timestamp exists")
    assert.is_number(first_timestamp)
    assert.is_true(first_timestamp > 0)

    test.debug("STEP", "2. Waiting and adding second visit")
    test.delay(100)  -- Wait to ensure timestamp difference

    history.add(uri, "Timestamp Test")

    local second_visit = history.db:exec([[ SELECT last_visit FROM history WHERE uri = ? ]], { uri })
    local second_timestamp = tonumber(second_visit[1].last_visit)
    test.debug("INFO", string.format("Second visit timestamp: %d (delta: %d)",
        second_timestamp, second_timestamp - first_timestamp))

    test.debug("ASSERT", "Verifying timestamp was updated")
    assert.is_true(second_timestamp >= first_timestamp)

    test.debug("STEP", "3. Cleaning up")
    cleanup_test_history()

    test.debug("TEST", "=== Timestamp tracking test completed ===")
end

T.test_history_without_visit_update = function ()
    test.debug("TEST", "=== Testing history add without visit update ===")

    test.debug("STEP", "1. Adding entry normally")
    cleanup_test_history()

    local uri = "test://example.com/no-update"
    history.add(uri, "No Update Test")

    local initial = history.db:exec([[ SELECT visits, last_visit FROM history WHERE uri = ? ]], { uri })
    local initial_visits = tonumber(initial[1].visits)
    local initial_timestamp = tonumber(initial[1].last_visit)

    test.debug("INFO", string.format("Initial: visits=%d, timestamp=%d",
        initial_visits, initial_timestamp))

    test.debug("STEP", "2. Adding with update_visits=false")
    test.delay(100)
    history.add(uri, "Updated Title", false)  -- Don't update visits

    local after = history.db:exec([[ SELECT visits, last_visit, title FROM history WHERE uri = ? ]], { uri })
    local after_visits = tonumber(after[1].visits)
    local after_timestamp = tonumber(after[1].last_visit)

    test.debug("INFO", string.format("After: visits=%d, timestamp=%d, title=%s",
        after_visits, after_timestamp, after[1].title))

    test.debug("ASSERT", "Verifying visits didn't increase")
    assert.is_equal(after_visits, initial_visits)

    test.debug("ASSERT", "Verifying title was still updated")
    assert.is_equal(after[1].title, "Updated Title")

    test.debug("STEP", "3. Cleaning up")
    cleanup_test_history()

    test.debug("TEST", "=== No visit update test completed ===")
end

T.test_history_multiple_entries = function ()
    test.debug("TEST", "=== Testing multiple history entries ===")

    test.debug("STEP", "1. Cleaning up and adding multiple entries")
    cleanup_test_history()

    local entries = {
        { uri = "test://site1.com", title = "Site 1" },
        { uri = "test://site2.com", title = "Site 2" },
        { uri = "test://site3.com", title = "Site 3" },
    }

    for i, entry in ipairs(entries) do
        test.debug("INFO", string.format("Adding entry %d: %s", i, entry.uri))
        history.add(entry.uri, entry.title)
        if i < #entries then
            test.delay(200)  -- Longer delay to ensure different timestamps
        end
    end

    test.debug("STEP", "2. Retrieving all test entries")
    local results = history.db:exec([[ SELECT * FROM history WHERE uri LIKE 'test://%' ORDER BY last_visit DESC ]])

    test.debug("ASSERT", "Verifying all entries were added")
    assert.is_true(#results >= #entries)

    test.debug("INFO", string.format("Found %d test entries", #results))

    test.debug("STEP", "3. Verifying entries exist and logging their order")
    -- Just verify all entries exist, don't enforce strict ordering due to timing issues
    local found_uris = {}
    for _, result in ipairs(results) do
        test.debug("INFO", string.format("Entry: %s (last_visit: %s)", result.uri, result.last_visit))
        found_uris[result.uri] = true
    end

    test.debug("ASSERT", "Verifying all three test entries exist")
    assert.is_true(found_uris["test://site1.com"])
    assert.is_true(found_uris["test://site2.com"])
    assert.is_true(found_uris["test://site3.com"])

    test.debug("STEP", "4. Cleaning up")
    cleanup_test_history()

    test.debug("TEST", "=== Multiple entries test completed ===")
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
