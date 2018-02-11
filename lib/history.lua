--- Save history in sqlite3 database.
--
-- This module provides browsing history support. Pages are saved to an on-disk
-- database automatically as the user browses.
--
-- The <luakit://history/> page is provided by the `history_chrome` module.
--
-- @module history
-- @copyright 2010-2011 Mason Larobina <mason.larobina@gmail.com>

local os = require("os")
local webview = require("webview")
local lousy = require("lousy")

local _M = {}

--- Path to history database.
-- @readwrite
_M.db_path = luakit.data_dir .. "/history.db"

local query_find_last
local query_insert
local query_update_visits
local query_update_title

-- Setup signals on history module
lousy.signal.setup(_M, true)

--- Connect to and initialize the history database.
function _M.init()
    -- Return if database handle already open
    if _M.db then return end

    _M.db = sqlite3{ filename = _M.db_path }
    _M.db:exec [[
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

    query_find_last = _M.db:compile [[
        SELECT id
        FROM history
        WHERE uri = ?
        ORDER BY last_visit DESC
        LIMIT 1
    ]]

    query_insert = _M.db:compile [[
        INSERT INTO history
        VALUES (NULL, ?, ?, ?, ?)
    ]]

    query_update_visits = _M.db:compile [[
        UPDATE history
        SET visits = visits + 1, last_visit = ?
        WHERE id = ?
    ]]

    query_update_title = _M.db:compile [[
        UPDATE history
        SET title = ?
        WHERE id = ?
    ]]
end

luakit.idle_add(_M.init)

--- Add a URI to the user's history.
-- @tparam string uri The URI to add to the user's history.
-- @tparam string title The title to associate with the URI.
-- @tparam[opt] boolean update_visits `false` if the last visit time for this URI
-- should not be updated.
-- @default `true`
function _M.add(uri, title, update_visits)
    if not _M.db then _M.init() end

    -- Ignore blank uris
    if not uri or uri == "" or uri == "about:blank" then return end
    -- Ignore luakit:// urls
    if string.find(uri, "^luakit://") then return end
    -- Ask user if we should ignore uri
    if _M.emit_signal("add", uri, title) == false then return end

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

--- Set of webviews on which to freeze history collection.
-- @type {[string]=boolean}
-- @readwrite
_M.frozen = setmetatable({}, { __mode = "k" })

webview.add_signal("init", function (view)
    -- Add items & update visit count
    view:add_signal("load-status", function (_, status)
        if view.private then return end
        if _M.frozen[view] then return end

        if status == "committed" then
            _M.add(view.uri)
        end
    end)
    -- Update titles
    view:add_signal("property::title", function ()
        if view.private then return end
        if _M.frozen[view] then return end

        local title = view.title
        if title and title ~= "" then
            _M.add(view.uri, title, false)
        end
    end)
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
