require "luasql.sqlite3"

database = {}

local util = lousy.util

function create_db()
    assert(database.conn:execute("BEGIN TRANSACTION"))

    assert(database.conn:execute[[
    CREATE TABLE IF NOT EXISTS urls(
        id INTEGER PRIMARY KEY NOT NULL,
        url TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL
    );
    ]])

    assert(database.conn:execute[[
    CREATE TABLE IF NOT EXISTS visits(
        id INTEGER PRIMARY KEY NOT NULL,
        url_id INTEGER NOT NULL,
        popularity INTEGER NOT NULL,
        last_access DATETIME NOT NULL
    );
    ]])

    assert(database.conn:execute[[
    CREATE TABLE IF NOT EXISTS bookmarks(
        id INTEGER PRIMARY KEY NOT NULL,
        url_id INTEGER UNIQUE,
        FOREIGN KEY(url_id) REFERENCES urls(id)
    );
    ]])

    assert(database.conn:execute[[
    CREATE TABLE IF NOT EXISTS tags(
        id INTEGER PRIMARY KEY NOT NULL,
        name TEXT NOT NULL UNIQUE
    );
    ]])

    assert(database.conn:execute[[
    CREATE TABLE IF NOT EXISTS taglist(
        id INTEGER PRIMARY KEY NOT NULL,
        bookmark_id INTEGER,
        tag_id INTEGER,
        FOREIGN KEY(bookmark_id) REFERENCES bookmark(id),
        FOREIGN KEY(tag_id) REFERENCES tags(id)
        UNIQUE (bookmark_id, tag_id) ON CONFLICT IGNORE
    );
    ]])

    -- Create the « delete cascade » triggers
    assert(database.conn:execute[[
    CREATE TRIGGER IF NOT EXISTS delete_url BEFORE DELETE ON urls
    FOR EACH ROW BEGIN
        DELETE FROM visits WHERE visits.url_id = old.id;
        DELETE FROM bookmarks WHERE bookmarks.url_id = old.id;
    END;
    ]])

    assert(database.conn:execute[[
    CREATE TRIGGER IF NOT EXISTS delete_bookmark BEFORE DELETE ON bookmarks
    FOR EACH ROW BEGIN
        DELETE FROM taglist WHERE taglist.bookmark_id = old.id;
    END;
    ]])

    assert(database.conn:execute[[
    CREATE TRIGGER IF NOT EXISTS delete_tags AFTER DELETE ON taglist
    FOR EACH ROW BEGIN
        DELETE FROM tags WHERE tags.id NOT IN (
            SELECT distinct tag_id from taglist
        );
    END;
    ]])

    assert(database.conn:execute[[
    CREATE TRIGGER IF NOT EXISTS insert_url AFTER INSERT ON urls
    FOR EACH ROW BEGIN
        insert into visits ("url_id", "popularity", "last_access")
        values (new.id, 1, date('now'));
    END
    ]])

    assert(database.conn:execute[[
    CREATE TRIGGER IF NOT EXISTS update_visit AFTER UPDATE ON visits BEGIN
        update visits set popularity=new.popularity+1 where id=new.id;
    END
    ]])

    assert(database.conn:execute[[
    CREATE INDEX IF NOT EXISTS visits_index ON visits
        ("url_id" ASC, "popularity" DESC)
    ]])

    assert(database.conn:execute[[
    CREATE VIEW IF NOT EXISTS tagged_bookmarks AS
        SELECT name, url FROM bookmarks, taglist, tags, urls
        WHERE taglist.tag_id = tags.id
        AND taglist.bookmark_id = bookmarks.id
        AND bookmarks.url_id = urls.id
        ORDER BY name
    ]])

    -- Remove olds entry from urls
    assert(database.conn:execute[[
    DELETE FROM urls
    WHERE id IN ( 
        SELECT url_id FROM visits 
        WHERE last_access < date('now' , '-1 month') 
    )
    ]])

    assert(database.conn:execute("END TRANSACTION"))
end


-- Insert the new page in the database or update the last visited time
function insert_url(url, title, update)
    title = title or ""
    local update = update or true
    local cur = database.conn:execute(string.format("select * from urls where url=%q", url))
    local treatment = ""
    local id = cur:fetch()
    cur:close()
    -- The urls does not exists, we create a new one
    if id == nil then
        treatment = string.format('insert into urls ("url", "title") values (%q, %q)', url, title)
        assert(database.conn:execute(treatment))
        cur = database.conn:execute("select max(id) from urls")
        id = cur:fetch()
        cur:close()
    elseif update then
        treatment = string.format("update visits set last_access=date('now') where url_id = %d", id)
        print(treatement)
        database.conn:execute(treatment)
    end
    return id
end

-- Request the database for getting the history
-- text is a pattern for filtering the urls
-- The urls are returned by popularity by default, but history can be specified
-- if order is "last_access"
function get_urls(text, order)
    order = order or "popularity"
    local pattern = ""
    if text then
        pattern = string.format("and url glob '*%s*'", text)
    end
    local request = [[
        select url, title from urls, visits 
        where urls.id = visits.url_id
        %s 
        order by visits.%s desc
        limit 50
        ]]
    cur = database.conn:execute(string.format(request, pattern, order))

    -- Create the table with the results
    local rows = {}
    if cur then
        repeat
            local row=cur:fetch({}, "a")
            if row then
                table.insert(rows, row )
            end
        until row==nil

        cur:close()
    end
    return rows
end

function add_bookmark(url, tags)
    local tags = tags or {}

    -- Create tags table from string
    if type(tags) == "string" then
        tags = util.string.split(tags)
    end

    assert(database.conn:execute("BEGIN TRANSACTION"))

    local url_id = insert_url(url, "", fase)

    local statement_bookmark = "INSERT OR IGNORE INTO bookmarks (url_id) VALUES (%d)"
    assert(database.conn:execute(string.format(statement_bookmark, url_id)))
    
    local statement_bookmark_id = "SELECT id FROM bookmarks WHERE url_id = %d"
    local cur = database.conn:execute(string.format(statement_bookmark_id, url_id))
    if not cur then
        -- This should not happen
        assert(database.conn:execute("ROLLBACK"))
        return false
    end
    local bookmark_id = cur:fetch()
    cur:close()

    -- Add the tags to the table
    -- luasql does not have prepared statement option…
    local statement_tag = "INSERT OR IGNORE INTO tags (name) VALUES (%q)"
    local statement_taglist = "INSERT OR IGNORE INTO taglist (bookmark_id, tag_id) VALUES (%q, %q)"
    local statement_tag_id = "SELECT id FROM tags WHERE name=%q"
    for tag = 1, #tags do
        assert(database.conn:execute(string.format(statement_tag, tags[tag])))
        cur = database.conn:execute(string.format(statement_tag_id, tags[tag]))
        if not cur then
            -- This should not happen
            assert(database.conn:execute("ROLLBACK"))
            return false
        end
        local tag_id = cur:fetch()
        cur:close()
        -- We need to be sure that the record is unique
        
        assert(database.conn:execute(string.format(statement_taglist, bookmark_id, tag_id)))
    end

    assert(database.conn:execute("END TRANSACTION"))
end

-- We instanciate the connexion only once
if database.conn == nil then
    local env = assert(luasql.sqlite3() )
    database.conn = env:connect(luakit.data_dir .. "/luakit.db")
    create_db()

    database.insert_url = insert_url
    database.get_urls = get_urls
    database.add_bookmark = add_bookmark
end
