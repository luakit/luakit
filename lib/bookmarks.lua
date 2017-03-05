--- Simple sqlite3 bookmarks.
--
-- @module bookmarks
-- @author Mason Larobina (mason.larobina@gmail.com)
-- @copyright 2010-2012 Mason Larobina (mason.larobina@gmail.com)

local lousy = require "lousy"
local capi = { luakit = luakit, sqlite3 = sqlite3 }
local keys = lousy.util.table.keys

local bookmarks = {}

lousy.signal.setup(bookmarks, true)

-- Path to users bookmarks database
bookmarks.db_path = capi.luakit.data_dir .. "/bookmarks.db"

function bookmarks.init()
    bookmarks.db = capi.sqlite3{ filename = bookmarks.db_path }
    bookmarks.db:exec [[
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

capi.luakit.idle_add(bookmarks.init)

function bookmarks.get(id)
    assert(type(id) == "number", "invalid bookmark id (number expected)")
    local rows = bookmarks.db:exec([[ SELECT * FROM bookmarks WHERE id = ? ]], { id })
    return rows[1]
end

function bookmarks.remove(id)
    assert(type(id) == "number", "invalid bookmark id (number expected)")

    bookmarks.emit_signal("remove", id)

    bookmarks.db:exec([[ DELETE FROM bookmarks WHERE id = ? ]], { id })
end

local function parse_tags(tags)
    local ret = {}
    local remains = string.gsub(tags, "%w[%w-]*",
        function (tag) ret[tag] = true return "" end)
    return ret, remains
end

local function update_tags(b, tags)
    table.sort(tags)
    tags = table.concat(tags, " ")
    bookmarks.db:exec([[ UPDATE bookmarks SET tags = ?, modified = ? WHERE id = ? ]],
        { tags, os.time(), b.id })
    bookmarks.emit_signal("update", b.id)
end

function bookmarks.tag(id, new_tags, replace)
    local b = assert(bookmarks.get(id), "bookmark not found")

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

function bookmarks.untag(id, name)
    local b = assert(bookmarks.get(id), "bookmark not found")
    if b.tags then
        local tags = parse_tags(b.tags)
        tags[name] = nil
        update_tags(b, keys(tags))
    end
end

-- Add new bookmark
function bookmarks.add(uri, opts)
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

    bookmarks.db:exec("INSERT INTO bookmarks VALUES (NULL, ?, ?, ?, ?, ?, ?)", {
        uri, opts.title or "", opts.desc or "", "", opts.created or os.time(),
        os.time() -- modified time (now)
    })

    local id = bookmarks.db:exec("SELECT last_insert_rowid() AS id")[1].id
    bookmarks.emit_signal("add", id)

    -- Add bookmark tags
    if opts.tags then bookmarks.tag(id, opts.tags) end

    return id
end

return bookmarks

-- vim: et:sw=4:ts=8:sts=4:tw=80
