-----------------------------------------------------------
-- Save history in sqlite3 database                      --
-- © 2010-2011 Mason Larobina <mason.larobina@gmail.com> --
-----------------------------------------------------------

local os = require "os"
local webview = webview
local table = table
local string = string
local lousy = require "lousy"
local capi = { luakit = luakit, sqlite3 = sqlite3 }

module "history"

-- Setup signals on history module
lousy.signal.setup(_M, true)

db = capi.sqlite3{ filename = capi.luakit.data_dir .. "/history.db" }
db:exec("PRAGMA synchronous = OFF; PRAGMA secure_delete = 1;")

create_table = [[
CREATE TABLE IF NOT EXISTS history (
    id INTEGER PRIMARY KEY,
    uri TEXT,
    title TEXT,
    visits INTEGER,
    last_visit INTEGER
);]]

db:exec(create_table)

function add(uri, title, update_visits)
    -- Ignore blank uris
    if not uri or uri == "" or uri == "about:blank" then return end
    -- Ask user if we should ignore uri
    if _M.emit_signal("add", uri, title) == false then return end

    local escape, format = lousy.util.sql_escape, string.format

    -- Find exsiting history item
    local results = db:exec(format([[SELECT * FROM history
        WHERE uri = %s ORDER BY last_visit DESC;]], escape(uri)))
    local item = results[1]

    -- Merge duplicate items into the first item
    if item and results[2] then
        local visits, ids = tonumber(item.visits), {}
        for i = 2, #results do
            local h = results[i]
            table.insert(ids, h.id)
            visits = visits + h.visits
        end
        -- Delete duplicates
        db:exec(format("DELETE FROM history WHERE id IN (%s);",
            table.concat(ids, ", ")))
        -- Update visits
        db:exec(format("UPDATE history SET visits = %d WHERE id = %d;",
            visits, item.id))
        -- Call add again now that the duplicates have been removed
        return add(uri, title, update_visits)
    end

    -- Update history item
    if item then
        local updates = {}
        -- Update title
        if title and title ~= "" then
            table.insert(updates, format("title = %s", escape(title)))
        end
        -- Update visit count & last access time
        if update_visits ~= false then
            table.insert(updates, "visits = visits + 1")
            table.insert(updates, format("last_visit = %d", os.time()))
        end
        -- Update item
        if #updates > 0 then
            db:exec(format("UPDATE history SET %s WHERE id = %d;",
                table.concat(updates, ", "), item.id))
        end

    -- Add new item
    else
        db:exec(format([[INSERT INTO history VALUES(NULL, %s, %s,
            1, %d);]], escape(uri), escape(title), os.time()))
    end
end

webview.init_funcs.save_hist = function (view)
    -- Add items
    view:add_signal("load-status", function (v, status)
        -- Don't add history items when in private browsing mode
        if v.enable_private_browsing then return end

        -- We use the "committed" status here because we are not interested in
        -- any intermediate uri redirects taken before reaching the real uri.
        -- The "property::title" signal takes care of filling in the history
        -- item title.
        if status == "committed" then
            add(v.uri)
        end
    end)
    -- Update titles
    view:add_signal("property::title", function (v)
        -- Don't add history items when in private browsing mode
        if v.enable_private_browsing then return end

        local title = v.title
        if title and title ~= "" then
            add(v.uri, title, false)
        end
    end)
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
