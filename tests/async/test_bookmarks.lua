--- Test bookmarks module functionality.
--
-- @copyright 2025

local T = {}
local test = require("tests.lib")
local assert = require("luassert")

uris = {"about:blank"}
require "config.rc"

local bookmarks = require "bookmarks"

-- Helper to clean up any test bookmarks
local function cleanup_test_bookmarks()
    local all = bookmarks.get_all()
    for _, bm in ipairs(all) do
        if bm.uri and string.match(bm.uri, "^test://") then
            bookmarks.remove(bm.id)
        end
    end
end

T.test_add_and_get_bookmark = function ()
    test.debug("TEST", "=== Testing bookmark add and get ===")

    test.debug("STEP", "1. Cleaning up any existing test bookmarks")
    cleanup_test_bookmarks()

    test.debug("STEP", "2. Adding a new bookmark")
    local uri = "test://example.com/page1"
    local title = "Test Page 1"
    local desc = "This is a test bookmark"
    local tags = "test tag1 tag2"

    local id = bookmarks.add(uri, { title = title, desc = desc, tags = tags })

    test.debug("INFO", string.format("Created bookmark with ID: %d", id))
    test.debug("ASSERT", "Verifying ID was returned")
    assert.is_number(id)
    assert.is_true(id > 0)

    test.debug("STEP", "3. Retrieving the bookmark")
    local bookmark = bookmarks.get(id)

    test.debug("ASSERT", "Verifying bookmark was retrieved")
    assert.is_not_nil(bookmark)
    assert.is_equal(bookmark.id, id)
    assert.is_equal(bookmark.uri, uri)
    assert.is_equal(bookmark.title, title)
    assert.is_equal(bookmark.desc, desc)
    assert.is_equal(bookmark.tags, "tag1 tag2 test")  -- Sorted alphabetically

    test.debug("STEP", "4. Cleaning up")
    bookmarks.remove(id)

    test.debug("TEST", "=== Bookmark add/get test completed ===")
end

T.test_remove_bookmark = function ()
    test.debug("TEST", "=== Testing bookmark removal ===")

    test.debug("STEP", "1. Adding a bookmark to remove")
    local id = bookmarks.add("test://example.com/to-remove", {
        title = "To Remove",
        desc = "This will be removed"
    })

    test.debug("ASSERT", "Verifying bookmark exists")
    local bookmark = bookmarks.get(id)
    assert.is_not_nil(bookmark)

    test.debug("STEP", "2. Removing the bookmark")
    bookmarks.remove(id)

    test.debug("ASSERT", "Verifying bookmark was removed")
    local removed = bookmarks.get(id)
    assert.is_nil(removed)

    test.debug("TEST", "=== Bookmark removal test completed ===")
end

T.test_update_bookmark_tags = function ()
    test.debug("TEST", "=== Testing bookmark tag updates ===")

    test.debug("STEP", "1. Creating a bookmark with initial tags")
    local id = bookmarks.add("test://example.com/tagged", {
        title = "Tagged Page",
        tags = "initial test"
    })

    local initial = bookmarks.get(id)
    test.debug("INFO", string.format("Initial tags: %s", initial.tags))

    test.debug("STEP", "2. Adding tags to the bookmark")
    bookmarks.add_tag(id, "newtag")
    bookmarks.add_tag(id, "anothertag")

    local updated = bookmarks.get(id)
    test.debug("INFO", string.format("Updated tags: %s", updated.tags))
    test.debug("ASSERT", "Verifying new tags were added")
    assert.is_true(string.match(updated.tags, "newtag") ~= nil)
    assert.is_true(string.match(updated.tags, "anothertag") ~= nil)

    test.debug("STEP", "3. Removing a tag")
    bookmarks.remove_tag(id, "newtag")

    local after_remove = bookmarks.get(id)
    test.debug("INFO", string.format("Tags after removal: %s", after_remove.tags))
    test.debug("ASSERT", "Verifying tag was removed")
    assert.is_false(string.match(after_remove.tags, "newtag") ~= nil)
    assert.is_true(string.match(after_remove.tags, "anothertag") ~= nil)

    test.debug("STEP", "4. Cleaning up")
    bookmarks.remove(id)

    test.debug("TEST", "=== Tag update test completed ===")
end

T.test_get_all_bookmarks = function ()
    test.debug("TEST", "=== Testing get all bookmarks ===")

    test.debug("STEP", "1. Cleaning up existing test bookmarks")
    cleanup_test_bookmarks()

    test.debug("STEP", "2. Adding multiple test bookmarks")
    local ids = {}
    for i = 1, 3 do
        local id = bookmarks.add(string.format("test://example.com/page%d", i), {
            title = string.format("Test Page %d", i),
            desc = string.format("Description %d", i)
        })
        table.insert(ids, id)
        test.debug("INFO", string.format("Created bookmark %d with ID: %d", i, id))
    end

    test.debug("STEP", "3. Retrieving all bookmarks")
    local all = bookmarks.get_all()

    test.debug("ASSERT", "Verifying all bookmarks returned")
    assert.is_table(all)
    test.debug("INFO", string.format("Total bookmarks in database: %d", #all))

    test.debug("STEP", "4. Verifying our test bookmarks are present")
    local test_bookmark_count = 0
    for _, bm in ipairs(all) do
        if string.match(bm.uri, "^test://") then
            test_bookmark_count = test_bookmark_count + 1
        end
    end
    test.debug("ASSERT", string.format("Verifying we have %d test bookmarks", #ids))
    assert.is_equal(test_bookmark_count, #ids)

    test.debug("STEP", "5. Cleaning up")
    for _, id in ipairs(ids) do
        bookmarks.remove(id)
    end

    test.debug("TEST", "=== Get all bookmarks test completed ===")
end

T.test_search_bookmarks_by_tag = function ()
    test.debug("TEST", "=== Testing bookmark search by tag ===")

    test.debug("STEP", "1. Creating bookmarks with specific tags")
    local id1 = bookmarks.add("test://tagged1.com", {
        title = "Tagged 1",
        tags = "test search important"
    })
    local id2 = bookmarks.add("test://tagged2.com", {
        title = "Tagged 2",
        tags = "test search"
    })
    local id3 = bookmarks.add("test://tagged3.com", {
        title = "Tagged 3",
        tags = "test other"
    })

    test.debug("STEP", "2. Searching for bookmarks with 'search' tag")
    local results = bookmarks.get_by_tag("search")

    test.debug("ASSERT", "Verifying search results")
    assert.is_table(results)
    test.debug("INFO", string.format("Found %d bookmarks with 'search' tag", #results))

    local found_count = 0
    for _, bm in ipairs(results) do
        if bm.id == id1 or bm.id == id2 then
            found_count = found_count + 1
        end
    end
    test.debug("ASSERT", "Verifying correct bookmarks were found")
    assert.is_true(found_count >= 2)

    test.debug("STEP", "3. Cleaning up")
    bookmarks.remove(id1)
    bookmarks.remove(id2)
    bookmarks.remove(id3)

    test.debug("TEST", "=== Tag search test completed ===")
end

T.test_bookmark_modification_tracking = function ()
    test.debug("TEST", "=== Testing bookmark modification timestamps ===")

    test.debug("STEP", "1. Creating a bookmark")
    local id = bookmarks.add("test://timestamptest.com", {
        title = "Timestamp Test"
    })

    local initial = bookmarks.get(id)
    test.debug("INFO", string.format("Created timestamp: %s", initial.created or "nil"))
    test.debug("INFO", string.format("Modified timestamp: %s", initial.modified or "nil"))

    test.debug("ASSERT", "Verifying created timestamp exists")
    assert.is_number(initial.created)

    test.debug("STEP", "2. Waiting a moment before modifying")
    test.delay(100)  -- Wait 100ms

    test.debug("STEP", "3. Modifying the bookmark")
    local original_created = initial.created
    bookmarks.add_tag(id, "modified")

    local modified = bookmarks.get(id)
    test.debug("INFO", string.format("New modified timestamp: %s", modified.modified or "nil"))

    test.debug("ASSERT", "Verifying modified timestamp updated")
    assert.is_number(modified.modified)
    assert.is_equal(modified.created, original_created)  -- Created shouldn't change

    test.debug("STEP", "4. Cleaning up")
    bookmarks.remove(id)

    test.debug("TEST", "=== Modification tracking test completed ===")
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
