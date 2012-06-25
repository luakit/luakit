-----------------------------------------------------------
-- Simple sqlite3 bookmarks                              --
-- © 2010-2012 Mason Larobina <mason.larobina@gmail.com> --
-----------------------------------------------------------

local lousy = require "lousy"
local string = string
local table = table
local type = type
local assert = assert
local ipairs = ipairs
local os = os
local error = error
local capi = { luakit = luakit, sqlite3 = sqlite3 }

module("bookmarks")

lousy.signal.setup(_M, true)

-- Path to users bookmarks database
db_path = capi.luakit.data_dir .. "/bookmarks.db"

function init()
    db = capi.sqlite3{ filename = _M.db_path }
    db:exec [[
        PRAGMA synchronous = OFF;
        PRAGMA secure_delete = 1;

        CREATE TABLE IF NOT EXISTS bookmarks (
            id INTEGER PRIMARY KEY,
            uri TEXT NOT NULL,
            title TEXT,
            desc TEXT,
            created INTEGER,
            modified INTEGER
        );

        CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY,
            name TEXT
        );

        CREATE TABLE IF NOT EXISTS tagmap (
            id INTEGER PRIMARY KEY,
            bookmark_id INTEGER,
            tag_id INTEGER,
            FOREIGN KEY(bookmark_id) REFERENCES bookmarks(id),
            FOREIGN KEY(tag_id) REFERENCES tags(id)
        );
    ]]
end

capi.luakit.idle_add(init)

-- Validate tag name
local function valid_tag_name(name)
    return not not string.match(name, "^%w[%w-]*$")
end

-- Return the tag id of a tag in the database (by it's name or id)
local function find_tag(name_or_id)
    -- Returns id of tag (if exists)
    if type(name_or_id) == "number" then
        local row = db:exec("SELECT * FROM tags WHERE id = ? LIMIT 1",
            { name_or_id })[1] or {}
        return row.id, row.name

    -- Returns id of tag name (if exists)
    elseif type(name_or_id) == "string" then
        assert(valid_tag_name(name_or_id), "invalid tag name: " .. name_or_id)
        local row = db:exec("SELECT id FROM tags WHERE name = ? LIMIT 1",
            { name_or_id })[1] or {}
        return row.id, row.name
    end

    error("invalid tag (name/id expected, got " .. type(name_or_id) .. ")")
end

-- Tag bookmark
function tag(bookmark_id, name_or_id)
    assert(type(bookmark_id) == "number", "invalid bookmark id (number expected)")

    -- Find tag (if exists)
    local tag_id, tag_name = find_tag(name_or_id)

    -- Create new tag
    if not tag_id then
        -- Add tag name to database
        db:exec("INSERT INTO tags VALUES (NULL, ?)", { name_or_id })
        tag_id = db:exec("SELECT last_insert_rowid() AS id")[1].id
        _M.emit_signal("new-tag", tag_id, name_or_id)
    end

    -- Tag bookmark
    db:exec("INSERT INTO tagmap VALUES(NULL, ?, ?)", { bookmark_id, tag_id })
    _M.emit_signal("tagged-bookmark", bookmark_id, tag_id, tag_name)
end

-- Deletes all orphaned tags
local function delete_orphan_tags()
    db:exec [[
        DELETE FROM tags WHERE id IN (
            SELECT tags.id FROM tags
            LEFT JOIN tagmap ON tags.id = tagmap.tag_id
            GROUP BY tags.id
            HAVING count(tagmap.id) == 0
        );
    ]]
end

-- Untag bookmark
function untag(bookmark_id, name_or_id)
    assert(type(bookmark_id) == "number", "invalid bookmark id (number expected)")

    -- Find tag (if exists)
    local tag_id, tag_name = find_tag(name_or_id)

    -- Remove tag from bookmark
    if tag_id then
        db:exec("DELETE FROM tagmap WHERE bid = ? AND tid = ?",
            { bookmark_id, tag_id })
        _M.emit_signal("untagged-bookmark", bookmark_id, tag_id, tag_name)
    end

    delete_orphan_tags()
end

-- Add new bookmark
function add(uri, opts)
    opts = opts or {}

    assert(type(uri) == "string" and #uri > 0, "invalid bookmark uri")
    assert(opts.title == nil or type(opts.title) == "string",
        "invalid bookmark title")
    assert(opts.desc == nil or type(opts.desc) == "string",
        "invalid bookmark description")

    -- Add new bookmark
    db:exec("INSERT INTO bookmarks VALUES (NULL, ?, ?, ?, ?, ?)",
        { uri, opts.title, opts.desc, os.time(), os.time() })

    -- Get new bookmark id
    local bookmark_id = db:exec("SELECT last_insert_rowid() AS id")[1].id

    opts.uri, opts.id = uri, bookmark_id
    _M.emit_signal("new-bookmark", opts)

    -- Add tags
    local tags = opts.tags
    if tags then
        -- Parse tags from string separated by spaces or commas
        if type(tags) == "string" then
            string.gsub(tags, "[^%s,]+", function (name)
                tag(bookmark_id, name)
            end)

        -- Or from table of tag names
        elseif type(tags) == "table" then
            for _, name in ipairs(tags) do
                tag(bookmark_id, name)
            end
        end
    end

    return bookmark_id
end


-- Delete bookmark
function remove(bookmark_id)
    assert(type(bookmark_id) == "number",
        "invalid bookmark id (number expected)")

    _M.emit_signal("removing-bookmark", bookmark_id)

    db:exec([[
        DELETE FROM tagmap WHERE bookmark_id = ?1;
        DELETE FROM bookmarks WHERE id = ?1;
    ]], { bookmark_id })

    delete_orphan_tags()
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
