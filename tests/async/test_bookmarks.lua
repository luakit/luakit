--- Test bookmarks module.
--
-- @copyright 2026

local assert = require "luassert"
local test = require "tests.lib"

uris = {"about:blank"}
require "config.rc"

local bookmarks = require "bookmarks"

local T = {}

T.test_bookmarks_crud = function ()
    test.wait_for_idle()

    -- Ensure database is initialized
    bookmarks.init()

    -- Verify clean starting state
    -- We can delete existing to be safe
    bookmarks.db:exec("DELETE FROM bookmarks")

    -- Add a bookmark
    local id = bookmarks.add("http://example.com", {
        title = "Example Domain",
        desc = "A simple example site",
        tags = "example test"
    })
    assert.is_number(id)

    -- Retrieve the bookmark
    local b = bookmarks.get(id)
    assert.is_table(b)
    assert.equal("http://example.com", b.uri)
    assert.equal("Example Domain", b.title)
    assert.equal("A simple example site", b.desc)
    assert.equal("example test", b.tags)

    -- Update tags (replace)
    bookmarks.tag(id, "updated tags", true)
    b = bookmarks.get(id)
    assert.equal("tags updated", b.tags) -- Note: tags are sorted alphabetically in bookmarks.tag!

    -- Update tags (append)
    bookmarks.tag(id, "new", false)
    b = bookmarks.get(id)
    assert.equal("new tags updated", b.tags) -- Sorted alphabetically: "new", "tags", "updated"

    -- Untag
    bookmarks.untag(id, "updated")
    b = bookmarks.get(id)
    assert.equal("new tags", b.tags)

    -- Remove the bookmark
    bookmarks.remove(id)
    assert.is_nil(bookmarks.get(id))
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
