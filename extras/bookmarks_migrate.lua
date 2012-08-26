local usage = [[Usage: luakit -c bookmark_migrate.lua [old bookmark db path] [new bookmark db path]

Imports bookmarks from old database schema:

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

To the new schema:

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

local old_db_path, new_db_path = unpack(uris)

if not old_db_path or not new_db_path then
    io.stdout:write(usage)
    luakit.quit(1)
end

old_db = sqlite3{ filename = old_db_path }
new_db = sqlite3{ filename = new_db_path }

local rows = old_db:exec [[
        SELECT b.*, group_concat(t.name, ' ') AS tags
        FROM bookmarks AS b
        LEFT JOIN tagmap AS map LEFT JOIN tags AS t
        ON map.bookmark_id = b.id AND map.tag_id = t.id
        GROUP BY b.id
    ]]

for i, b in ipairs(rows) do
    print(string.format("IMPORT (%q, %q, %q, %q, %d, %d)",
        b.uri or "", b.title or "", b.desc or "", b.tags or "",
        b.created or 0, b.modified or 0))

    new_db:exec("INSERT INTO bookmarks VALUES (NULL, ?, ?, ?, ?, ?, ?)", {
        b.uri or "", b.title or "", b.desc or "", b.tags or "",
        b.created or os.time(), b.modified or os.time()
    })
end

print("Import finished.")

print("\nVacuuming database...")
new_db:exec "VACUUM"
print("Vacuum done.")

luakit.quit(0)
