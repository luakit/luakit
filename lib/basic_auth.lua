-- Store HTTP basic auth credentials in a SQLite database.
-- Author: Justin Forest <hex@umonkey.net>

local io = io
local capi = { luakit = luakit, soup = soup, sqlite3 = sqlite3 }
local info = info
local warn = warn
local lousy = require "lousy"
local sql_escape = lousy.util.sql_escape
local parse_uri = lousy.uri.parse


create_table = [[CREATE TABLE IF NOT EXISTS basic_auth (
	domain TEXT,
	login TEXT,
	password TEXT
);]]

create_index = [[CREATE UNIQUE INDEX IF NOT EXISTS basic_auth_url_idx ON basic_auth (domain)]]

db = capi.sqlite3{ filename = capi.luakit.data_dir .. "/basic_auth.db" }
db:exec(create_table)
db:exec(create_index)


-- Returns authentication data for URL.
local function load_auth(page_uri)
	local uri = parse_uri(page_uri)
	if not uri then
		warn("Unable to parse page URI: %s", page_uri)
		return
	end

	info("Authenticating page <%s>, host name = %s", page_uri, uri.host)

	local sql = string.format("SELECT login, password FROM basic_auth WHERE domain = %s;", sql_escape(uri.host))
	info("SQL: %s", sql)

	local rows = db:exec(sql)
	if not rows[1] then
		info("No stored credentials for %s", uri.host)
		return nil
	end

	if rows[1] then
		info("Pre-populating login dialog with user %s", rows[1].login)
		return rows[1].login, rows[1].password
	end
end


-- Save authentication data.
local function save_auth(page_uri, login, password)
	local uri = parse_uri(page_uri)
	if not uri then
		warn("Unable to parse URI: %s", page_uri)
		return
	end

	local sql = string.format("REPLACE INTO basic_auth (domain, login, password) VALUES (%s, %s, %s)",
		sql_escape(uri.host), sql_escape(login), sql_escape(password))
	info("SQL: %s", sql)

	db:exec(sql)
end


window.init_funcs.handle_basic_auth = function (w)
	capi.soup.add_signal("authenticate", load_auth)
	capi.soup.add_signal("store-password", save_auth)
end
