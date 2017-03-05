--- Save history in sqlite3 database.
--
-- @module history
-- @copyright 2010-2011 Mason Larobina <mason.larobina@gmail.com>

local os = require("os")
local webview = require("webview")
local lousy = require("lousy")
local capi = { luakit = luakit, sqlite3 = sqlite3 }

local history = {}

-- Path of history sqlite database to open/create/update
history.db_path = capi.luakit.data_dir .. "/history.db"

local query_find_last
local query_insert
local query_update_visits
local query_update_title

-- Setup signals on history module
lousy.signal.setup(history, true)

function history.init()
    -- Return if database handle already open
    if history.db then return end

    history.db = capi.sqlite3{ filename = history.db_path }
    history.db:exec [[
        PRAGMA synchronous = OFF;
        PRAGMA secure_delete = 1;

        CREATE TABLE IF NOT EXISTS history (
            id INTEGER PRIMARY KEY,
            uri TEXT,
            title TEXT,
            visits INTEGER,
            last_visit INTEGER
        );
    ]]

    query_find_last = history.db:compile [[
        SELECT id
        FROM history
        WHERE uri = ?
        ORDER BY last_visit DESC
        LIMIT 1
    ]]

    query_insert = history.db:compile [[
        INSERT INTO history
        VALUES (NULL, ?, ?, ?, ?)
    ]]

    query_update_visits = history.db:compile [[
        UPDATE history
        SET visits = visits + 1, last_visit = ?
        WHERE id = ?
    ]]

    query_update_title = history.db:compile [[
        UPDATE history
        SET title = ?
        WHERE id = ?
    ]]
end

capi.luakit.idle_add(history.init)

function history.add(uri, title, update_visits)
    if not history.db then history.init() end

    -- Ignore blank uris
    if not uri or uri == "" or uri == "about:blank" then return end
    -- Ignore luakit:// urls
    if string.find(uri, "^luakit://") then return end
    -- Ask user if we should ignore uri
    if history.emit_signal("add", uri, title) == false then return end

    -- Find existing item
    local item = (query_find_last:exec{uri})[1]
    if item then
        if update_visits ~= false then
            query_update_visits:exec{os.time(), item.id}
        end
        if title then
            query_update_title:exec{title, item.id}
        end
    else
        query_insert:exec{uri, title, 1, os.time()}
    end
end

webview.init_funcs.save_hist = function (view)
    -- Add items & update visit count
    view:add_signal("load-status", function (_, status)
        -- Don't add history items when in private browsing mode
        if view.enable_private_browsing then return end

        if status == "committed" then
            history.add(view.uri)
        end
    end)
    -- Update titles
    view:add_signal("property::title", function ()
        -- Don't add history items when in private browsing mode
        if view.enable_private_browsing then return end

        local title = view.title
        if title and title ~= "" then
            history.add(view.uri, title, false)
        end
    end)
end

return history

-- vim: et:sw=4:ts=8:sts=4:tw=80
