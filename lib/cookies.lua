------------------------------------------------------------
-- Cross-instance luakit cookie management (with sqlite3) --
-- © 2011 Mason Larobina <mason.larobina@gmail.com>       --
------------------------------------------------------------

local math = require "math"
local string = string
local ipairs = ipairs
local pairs = pairs
local print = print
local lousy = require "lousy"
local capi = {
    luakit = luakit,
    soup = soup,
    sqlite3 = sqlite3,
    timer = timer
}
local time, floor = luakit.time, math.floor

module "cookies"

db_path = capi.luakit.data_dir .. "/cookies.db"

-- Last access time
local atime = 0

-- Set max session age to 3600
session_timeout = 3600
force_session_timeout = true

-- Setup signals on module
lousy.signal.setup(_M, true)

-- Return microseconds from the unixtime epoch
function micro()
    return floor(time() * 1e6)
end

function init()
    -- Return if database handle already open
    if db then return end

    db = capi.sqlite3{ filename = _M.db_path }
    db:exec [[
        PRAGMA synchronous = OFF;
        PRAGMA secure_delete = 1;

        CREATE TABLE IF NOT EXISTS moz_cookies (
            id INTEGER PRIMARY KEY,
            name TEXT,
            value TEXT,
            host TEXT,
            path TEXT,
            expiry INTEGER,
            lastAccessed INTEGER,
            isSecure INTEGER,
            isHttpOnly INTEGER
        );

        CREATE TRIGGER IF NOT EXISTS delete_old_cookie
            BEFORE INSERT ON moz_cookies
            BEGIN
                DELETE FROM moz_cookies
                WHERE (
                    host == new.host AND
                    path == new.path AND
                    name == new.name
                );
            END;
    ]]

    query_all_since = db:compile [[
        SELECT id, name, value, host AS domain, path, expiry AS expires,
            isSecure AS secure, isHttpOnly AS http_only
        FROM moz_cookies
        WHERE lastAccessed >= ? AND expiry >= ?
    ]]

    query_insert = db:compile [[
        INSERT INTO moz_cookies
        VALUES(NULL, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]

    query_expire = db:compile [[
        UPDATE moz_cookies
        SET expiry = 0, value = NULL, lastAccessed = ?
        WHERE host = ? AND path = ? AND name = ?
    ]]

    query_delete_expired = db:compile [[
        DELETE FROM moz_cookies
        WHERE expiry < ? AND lastAccessed < ?
    ]]
end

-- Open database handle after window has time to open
capi.luakit.idle_add(init)

-- Load all cookies after the last check time
capi.soup.add_signal("request-started", function ()
    if not db then init() end

    local old_atime, new_atime = atime, micro()
    -- Rate limit select queries to 1 p/s
    if (new_atime - old_atime) > 1e6 then
        local cookies = query_all_since:exec{ old_atime,
            -- On first exec don't load any expired cookies
            (atime == 0 and time()) or 0 }
        atime = new_atime
        if cookies[1] then
            capi.soup.add_cookies(cookies)
        end
    end
end)

capi.soup.add_signal("cookie-changed", function (old, new)
    if new then
        if _M.emit_signal("accept-cookie", new) == false then
            new.expires = 0 -- expire cookie
            capi.soup.add_cookies{new}
            return
        end

        -- Set session cookie timeout & keep session cookies in memory
        if new.expires == -1 then
            if _M.force_session_timeout then
                new.expires = math.ceil(time() + _M.session_timeout)
                capi.soup.add_cookies{new}
            end
            return
        end

        -- Insert new cookie
        query_insert:exec {
            new.name,
            new.value,
            new.domain,
            new.path,
            new.expires,
            micro(),
            new.secure,
            new.http_only
        }
        return
    end

    -- Expire old cookie
    if old then
        query_expire:exec {
            micro(), -- lastAccessed
            old.domain,
            old.path,
            old.name
        }
    end
end)

-- When closing luakit delete most expired cookies.
capi.luakit.add_signal("can-close", function ()
    if query_delete_expired then
        local t = time()
        query_delete_expired:exec{ t, (t - 86400) * 1e6 }
    end
end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
