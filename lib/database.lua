require "luasql.sqlite3"

database = {}

function create_db()
    assert(database.conn:execute("BEGIN TRANSACTION"))

    assert(database.conn:execute[[
    CREATE TABLE IF not EXISTS urls(
        id INTEGER PRIMARY KEY NOT NULL,
        url TEXT NOT NULL UNIQUE
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
    CREATE VIEW IF NOT EXISTS history AS
        select url from urls, visits
        where urls.id = visits.url_id
        order by visits.popularity desc;
    ]])

    assert(database.conn:execute[[
    CREATE TRIGGER  IF NOT EXISTS delete_url BEFORE DELETE ON urls
    BEGIN
        DELETE FROM visits WHERE visits.url_id = old.id;
    END;
    ]])

    assert(database.conn:execute[[
    CREATE TRIGGER IF NOT EXISTS insert_url AFTER INSERT ON urls
    BEGIN
        insert into visits ("url_id", "popularity", "last_access") values (new.id, 1, date('now'));
    END
    ]])

    assert(database.conn:execute[[
    CREATE TRIGGER IF NOT EXISTS update_visit AFTER UPDATE ON visits BEGIN
        update visits set popularity=new.popularity+1 where id=new.id;
    END
    ]])

    assert(database.conn:execute[[
    CREATE INDEX IF NOT EXISTS visits_index ON visits ("url_id" ASC, "popularity" DESC)
    ]])

    assert(database.conn:execute("END TRANSACTION"))
end


-- Insert the new page in the database or update the last visited time
function insert_url(url, title)
    title = title or ""
    local cur = database.conn:execute(string.format("select * from urls where url=%q", url))
    local treatment = ""
    local id = cur:fetch()
    if id == nil then
        treatment = string.format('insert into urls ("url", "title") values (%q, %q)', url, title)
    else
        treatment = string.format("update visits set last_access=date('now') where url_id = %d", id)
    end
    cur:close()
    database.conn:execute(treatment)
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
    repeat
        local row=cur:fetch({}, "a")
        if row then
            table.insert(rows, row )
        end
    until row==nil

    cur:close()
    return rows
end

-- We instanciate the connexion only once
if database.conn == nil then
    local env = assert(luasql.sqlite3() )
    database.conn = env:connect(luakit.data_dir .. "/luakit.db")
    create_db()

    database.insert_url = insert_url
    database.get_urls = get_urls
end
