-- We need sqlite to register our history
require "luasql.sqlite3"

function create_db()
    assert(conn:execute("BEGIN TRANSACTION"))

    assert(conn:execute[[
    CREATE TABLE IF not EXISTS urls(
        id INTEGER PRIMARY KEY NOT NULL,
        url TEXT NOT NULL UNIQUE
    );
    ]])

    assert(conn:execute[[
    CREATE TABLE IF NOT EXISTS visits(
        id INTEGER PRIMARY KEY NOT NULL,
        url_id INTEGER NOT NULL,
        counter INTEGER NOT NULL,
        last_acces DATETIME NOT NULL
    );
    ]])

    assert(conn:execute[[
    CREATE VIEW IF NOT EXISTS history AS
        select url from urls, visits
        where urls.id = visits.url_id
        order by visits.counter desc;
    ]])

    assert(conn:execute[[
    CREATE TRIGGER  IF NOT EXISTS delete_url BEFORE DELETE ON urls
    BEGIN
        DELETE FROM visits WHERE visits.url_id = old.id;
    END;
    ]])

    assert(conn:execute[[
    CREATE TRIGGER IF NOT EXISTS insert_url AFTER INSERT ON urls
    BEGIN
        insert into visits ("url_id", "counter", "last_acces") values (new.id, 1, date('now'));
    END
    ]])

    assert(conn:execute[[
    CREATE TRIGGER IF NOT EXISTS update_visit AFTER UPDATE ON visits BEGIN
        update visits set counter=new.counter+1 where id=new.id;
    END
    ]])

    assert(conn:execute[[
    CREATE INDEX IF NOT EXISTS visits_index ON visits ("url_id" ASC, "counter" DESC)
    ]])

    assert(conn:execute("END TRANSACTION"))
end

env = assert(luasql.sqlite3() )
conn = env:connect(luakit.data_dir .. "/history.sqlite")
create_db()

history={}
history.table = {}
history.index = 1

-- Insert the new page in the database or update the last visited time
function insert (url)
    local cur = conn:execute(string.format("select id from urls where url=%q", url))
    local treatment = ""
    if cur:fetch() == nil then
        treatment = string.format('insert into urls ("url") values (%q)', url)
    else
        treatment = string.format("update visits set last_acces=date('now') where url_id = (select urls.id from urls where url=%q)", url)
    end
    conn:execute(treatment)
    cur:close()
end

-- Add signal to register each page in the database
webview.init_funcs.save_hist = function (view)
    view:add_signal("load-status", function (v, status)
        if status == "first-visual" then
            -- We remove extra parameters from the request
            local url = string.gsub(v.uri, "?.*", "")
            pcall(insert, url)
        end
    end)
end

-- History mode
new_mode("history", {
    enter = function (w)
        w:set_prompt("-- HISTORY --")
        w:set_input(":")
    end,
    changed = function (w, text)
        -- Auto-exit command mode if user backspaces ":" in the input bar.
        if not string.match(text, "^:") then 
            w:set_mode()
            return
        end

        local cmd = string.sub(text, 2)
        cur = conn:execute(string.format("select url from history where url like '%%%s%%' limit 15", cmd))

        -- Create the table with the results
        history.table = {}
        history.index = 1
        repeat
            local row=cur:fetch()
            table.insert(history.table,row)
        until row==nil
        w:set_prompt(history.table[1])

        cur:close()

    end,
    activate = function (w, text)
        local cmd = string.sub(text, 2)
        cmd = history.table[history.index]

        w:set_mode()
        history.table = {}
        history.index = 1
        pcall(w.match_cmd, w, "o "..cmd)
    end,
})
