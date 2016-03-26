local assert    = assert
local type      = type
local string    = string
local cookies_lib = require("cookies")

local capi = {
    luakit = luakit,
    soup = soup,
    timer = timer,
    sqlite3 = sqlite3 
}

module("cookie_filter")

-- A table of all cookies sent, indexed first by domain and then by name.
-- Used by cookie_filter_chrome to display the list of allowed and blocked
-- cookies.
cookies = {}

-- Fitting for cookie_filter_chrome.refresh_views()
refresh_views = function()
    -- Dummy.
end

-- Database queries {{{
db = capi.sqlite3{ filename = capi.luakit.data_dir .. "/cookie_filter.db" }
db:exec("PRAGMA synchronous = OFF; PRAGMA secure_delete = 1;")

query_create = db:compile [[
    CREATE TABLE IF NOT EXISTS filter (
        id INTEGER PRIMARY KEY,
        domain TEXT,
        name TEXT,
        allow INTEGER
    );]]

query_create:exec()

local query_insert = db:compile [[ INSERT INTO filter VALUES (NULL, ?, ?, ?) ]]
local query_update = db:compile [[ UPDATE filter SET allow = ? WHERE id == ?  ]]
local query_select = db:compile [[ SELECT * FROM filter WHERE domain == ? AND name == ? ]]
-- }}}
-- Cookie filtering get / set {{{
get = function (domain, name)
    assert(type(domain) == "string")
    assert(type(name) == "string")

    local rows = query_select:exec{domain, name}
    return rows[1] and rows[1].allow == 1 or false
end

set = function (domain, name, allow)
    assert(type(domain) == "string")
    assert(type(name) == "string")

    local rows = query_select:exec{domain, name}
    if rows[1] then
        query_update:exec{allow, rows[1].id}
    else
        query_insert:exec{domain, name, allow}
    end

    refresh_views()
end
-- }}}

local function record_cookie(cookie)
    if cookies[cookie.domain] == nil then
        cookies[cookie.domain] = {}
    end
    cookies[cookie.domain][cookie.name] = cookie
end

cookies_lib.add_signal("accept-cookie", function (cookie)
    record_cookie(cookie)
    return get(cookie.domain, cookie.name)
end)
