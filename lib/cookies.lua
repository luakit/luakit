------------------------------------------------------------
-- Cross-instance luakit cookie management (with sqlite3) --
-- (C) 2011 Mason Larobina <mason.larobina@gmail.com>     --
------------------------------------------------------------

require "math"
local os = require "os"
local io = require "io"
local assert = assert
local string = string
local table = table
local print = print
local ipairs = ipairs
local capi = { luakit = luakit, soup = soup, sqlite3 = sqlite3, timer = timer }
local time, floor = luakit.time, math.floor

module "cookies"

-- Return microseconds from the unixtime epoch
function micro()
    return floor(time() * 1e6)
end

-- Escape values for SQL queries. In sqlite3: "A string constant is formed
-- by enclosing the string in single quotes ('). A single quote within the
-- string can be encoded by putting two single quotes in a row - as in
-- Pascal." Read: http://sqlite.org/lang_expr.html
function escape(s)
    return "'" .. string.gsub(s, "'", "''") .. "'"
end

-- Last cookie check time
local checktime = 0

-- Check for new cookies every 60 seconds. A new cookie has a lastAccessed
-- time greater than the last checktime. It is important that this timer is
-- always running to see time-critical cookie deletions which are only
-- present in the cookie jar for 90 seconds before being purged.
local checktimer = capi.timer{ interval = 60e3 }

-- Open cookies sqlite database at $XDG_DATA_HOME/luakit/cookies.db
db = capi.sqlite3{ filename = capi.luakit.data_dir .. "/cookies.db" }
-- Make reads/writes faster
db:exec("PRAGMA synchronous = OFF; PRAGMA secure_delete = 1;")

-- Echo executed queries, number of rows changed & time each query took
if capi.luakit.verbose then
    db:add_signal("execute", function (_, sql, updates, time)
        io.stderr:write(string.format("%s\nQuery OK, %d rows affected (%f sec)\n",
            string.gsub(sql, "[%s\n]+", " "), updates, time))
    end)
end

create_table = [[
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
);]]

query_all_since = [[SELECT id, name, value, host AS domain, path,
    expiry AS expires, isSecure AS secure, isHttpOnly AS http_only
FROM moz_cookies
WHERE lastAccessed >= %d;]]

query_insert = [[INSERT INTO moz_cookies
VALUES(NULL, %s, %s, %s, %s, %d, %d, %d, %d);]]

query_expire = [[UPDATE moz_cookies
SET expiry=0, lastAccessed=%d
WHERE host=%s AND name=%s AND path=%s;]]

query_delete = [[DELETE FROM moz_cookies
WHERE host=%s AND name=%s AND path=%s;]]

query_delete_expired = [[DELETE FROM moz_cookies
WHERE expiry == 0 AND lastAccessed < %d;]]

query_delete_session = [[DELETE FROM moz_cookies
WHERE expiry == -1;]]

-- Create table (if not exists)
db:exec(create_table)

-- Load all cookies after the last check time
function load_new_cookies(purge)
    local ctime = micro()

    -- Delete all expired cookies older than 90 seconds
    if purge ~= false then
        db:exec(string.format(query_delete_expired, ctime - 90e6))
    end

    -- Get new cookies from the db
    local cookies = db:exec(string.format(query_all_since, checktime))

    -- Update checktime for next run
    checktime = ctime

    -- Convert query results into suitable cookie tables
    for i, c in ipairs(cookies) do
        c.secure = c.secure == "1"
        c.http_only = c.http_only == "1"
    end

    -- Add new cookies to the cookiejar
    if cookies[1] then
        capi.soup.add_cookies(cookies)
    end
end

capi.soup.add_signal("cookie-changed", function (old, new)
    local e = escape
    if new then
        -- Delete all previous matching/expired cookies.
        db:exec(string.format(query_delete,
            e(new.domain), -- WHERE = host
            e(new.name), -- WHERE = name
            e(new.path))) -- WHERE = path

        -- Insert new cookie
        db:exec(string.format(query_insert,
            e(new.name), -- name
            e(new.value), -- value
            e(new.domain), -- host
            e(new.path), -- path
            new.expires or -1, -- expiry
            micro(), -- lastAccessed
            new.secure and 1 or 0, -- isSecure
            new.http_only and 1 or 0)) -- isHttpOnly

    -- Expire old cookie
    elseif old then
        db:exec(string.format(query_expire,
            micro(), -- lastAccessed
            e(old.domain), -- WHERE = host
            e(old.name), -- WHERE = name
            e(old.path))) -- WHERE = path
    end
end)

capi.soup.add_signal("request-started", function (uri)
    -- Load all new cookies since last update
    load_new_cookies(false)
end)

-- Setup checktimer timeout callback function and start timer.
checktimer:add_signal("timeout", load_new_cookies)
checktimer:start()
