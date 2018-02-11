--- Simple sqlite3 bookmarks.
--
-- This module provides a Lua API for accessing and modifying bookmarks,
-- but does not provide a user interface. In order to add/remove bookmarks and
-- view all bookmarks in a single page, you'll need the `bookmarks_chrome`
-- module.
--
-- @module bookmarks
-- @author Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2012 Mason Larobina <mason.larobina@gmail.com>

local lousy = require "lousy"
local keys = lousy.util.table.keys

local _M = {}

lousy.signal.setup(_M, true)

--- Path to bookmarks database.
-- @readwrite
_M.db_path = luakit.data_dir .. "/bookmarks.db"

--- Connect to and initialize the bookmarks database.
function _M.init()
    _M.db = sqlite3{ filename = _M.db_path }
    _M.db:exec [[
        PRAGMA synchronous = OFF;
        PRAGMA secure_delete = 1;

        CREATE TABLE IF NOT EXISTS bookmarks (
            id INTEGER PRIMARY KEY,
            uri TEXT NOT NULL,
            title TEXT NOT NULL,
            desc TEXT NOT NULL,
            tags TEXT NOT NULL,
            created INTEGER,
            modified INTEGER
        );
    ]]
end

luakit.idle_add(_M.init)

--- Get a bookmark entry by its ID number.
-- @tparam number id The ID of the bookmark entry to get.
-- @treturn table The bookmark entry.
function _M.get(id)
    assert(type(id) == "number", "invalid bookmark id (number expected)")
    local rows = _M.db:exec([[ SELECT * FROM bookmarks WHERE id = ? ]], { id })
    return rows[1]
end

--- Remove a bookmark entry by its ID number.
-- @tparam number id The ID of the bookmark entry to remove.
function _M.remove(id)
    assert(type(id) == "number", "invalid bookmark id (number expected)")

    _M.emit_signal("remove", id)

    _M.db:exec([[ DELETE FROM bookmarks WHERE id = ? ]], { id })
end

local function parse_tags(tags)
    local ret = {}
    local remains = string.gsub(tags, "%S+",
        function (tag) ret[tag] = true return "" end)
    return ret, remains
end

local function update_tags(b, tags)
    table.sort(tags)
    tags = table.concat(tags, " ")
    _M.db:exec([[ UPDATE bookmarks SET tags = ?, modified = ? WHERE id = ? ]],
        { tags, os.time(), b.id })
    _M.emit_signal("update", b.id)
end

--- Update the tags on a bookmark entry.
-- @tparam number id The ID of the bookmark entry to update.
-- @tparam table|string new_tags The tags to add to the bookmark entry.
-- @tparam boolean replace `true` if the new tags should replace all existing
-- tags.
function _M.tag(id, new_tags, replace)
    local b = assert(_M.get(id), "bookmark not found")

    if type(new_tags) == "table" then
        new_tags = table.concat(new_tags, " ")
    end

    local all_tags = string.format("%s %s", new_tags,
        (not replace and b.tags) or "")

    local tags, remains = parse_tags(all_tags)

    if string.find(remains, "[^%s,]") then
        error("invalid tags: " ..  remains)
    end

    update_tags(b, keys(tags))
end

--- Remove a tag from a bookmark entry.
-- @tparam number id The ID of the bookmark entry to update.
-- @tparam string name The tag to remove from the bookmark entry.
function _M.untag(id, name)
    local b = assert(_M.get(id), "bookmark not found")
    if b.tags then
        local tags = parse_tags(b.tags)
        tags[name] = nil
        update_tags(b, keys(tags))
    end
end

--- Add a new bookmark entry.
-- @tparam string uri The URI to bookmark.
-- @tparam table opts A table of options.
-- @treturn number The ID of the new bookmark entry.
function _M.add(uri, opts)
    opts = opts or {}

    assert(type(uri) == "string" and #uri > 0, "invalid bookmark uri")
    assert(opts.title == nil or type(opts.title) == "string",
        "invalid bookmark title")
    assert(opts.desc == nil or type(opts.desc) == "string",
        "invalid bookmark description")
    assert(opts.created == nil or type(opts.created) == "number",
        "invalid creation time")

    -- Default to http:// scheme if none provided
    if not string.match(uri, "^%w+://") then
        uri = "http://" .. uri
    end

    _M.db:exec("INSERT INTO bookmarks VALUES (NULL, ?, ?, ?, ?, ?, ?)", {
        uri, opts.title or "", opts.desc or "", "", opts.created or os.time(),
        os.time() -- modified time (now)
    })

    local id = _M.db:exec("SELECT last_insert_rowid() AS id")[1].id
    _M.emit_signal("add", id)

    -- Add bookmark tags
    if opts.tags then _M.tag(id, opts.tags) end

    return id
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
