-- We need sqlite to register our history
require "luasql.sqlite3"

-- Get environment we need from luakit libs
local new_mode = new_mode
local add_cmds = add_cmds
local add_binds = add_binds
local menu_binds = menu_binds
local webview = webview
local lousy = require "lousy"

history = {}
history.mode = "command"

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

-- Insert the new page in the database or update the last visited time
function insert (url)
    local cur = conn:execute(string.format("select id from urls where url='%s'", url))
    local treatment = ""
    if cur:fetch() == nil then
        treatment = string.format('insert into urls ("url") values ("%s")', url)
    else
        treatment = string.format("update visits set last_acces=date('now') where url_id = (select urls.id from urls where url='%s')", url)
    end
    conn:execute(treatment)
    cur:close()
end

-- We register each visited page
webview.init_funcs.save_hist = function (view)
    view:add_signal("load-status", function (v, status)

        if status == "first-visual" then
            -- We remove extra parameters from the request
            local url = string.gsub(v.uri, "?.*", "")
            pcall(insert, url)
        end

    end)
end

-- Request the database for getting the history
-- The urls are returned by popularity ( frequency )
function show_history(w, text)
        local cmd = string.sub(text, 2)
        cur = conn:execute(string.format("select url from history where url like '%%%s%%' limit 50", cmd))

        -- Create the table with the results
        local rows = {}
        repeat
            local row=cur:fetch()
            if row then
                table.insert(rows, { row, uri = row })
            end
        until row==nil

        cur:close()
        w.menu:build(rows)
end

-- Go to the requested url
function navigate(w)
    local row = w.menu:get()
    if row and row.uri then
        w:navigate(row.uri)
        w:set_mode()
    end
end

-- Switch to insert or command mode
function switch(mode, w)
    if mode == "command" then
        history.mode = "command"
        w:set_input()
        w:notify("Use j/k to move,f filter, o open, t tabopen, w winopen.", false)
    else
        w:set_input(":")
        history.mode = "insert"
        w:notify("Filter the url and press return to validate", false)
    end
end

-- Set the mode
new_mode("history", {
    enter = function (w)
        show_history(w, "%")
        switch("insert", w)
    end,
    
    changed = function (w, text)
        -- Return to command mode
        if not string.match(text, "^:") then 
            switch("command", w)
            return
        end
        show_history(w, text)

    end,
    
    leave = function (w)
        w.menu:hide()
    end,

})

local cmd = lousy.bind.cmd
add_cmds({
    cmd("hist[ory]",
        function (w) w:set_mode("history") end),
})

local key = lousy.bind.key
add_binds("history", lousy.util.table.join({

    -- Open hist item
    key({}, "Return",
        function (w)
            if history.mode == "command" then
                navigate(w)
            else
                switch("command", w)
            end
        end),

    key({}, "j",
        function (w)
            if history.mode == "insert" then
                w:insert_cmd("j")
            else
                w.menu:move_down()
            end
        end),

    key({}, "k",
        function (w)
            if history.mode == "insert" then
                w:insert_cmd("k")
            else
                w.menu:move_up()
            end
        end),

    -- Filter the history
    key({}, "f",
        function (w)
            if history.mode == "command" then
                switch("insert", w)
            else
                w:insert_cmd("f")
            end
        end),

    -- Open hist item
    key({}, "o",
        function (w)
            if history.mode == "command" then
                navigate(w)
            else
                w:insert_cmd("o")
            end
        end),

    -- Open hist item in background tab
    key({}, "t",
        function (w)
            if history.mode == "command" then
                local row = w.menu:get()
                if row and row.uri then
                    w:set_mode()
                    w:new_tab(row.uri, false)
                end
            else
                w:insert_cmd("t")
            end
        end),

    -- Open hist item in new window
    key({}, "w",
        function (w)
            if history.mode == "command" then
                local row = w.menu:get()
                if row and row.uri then
                    w:set_mode()
                    window.new({row.uri})
                end
            else
                w:insert_cmd("w")
            end
        end),


}, menu_binds))
