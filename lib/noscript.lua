--------------------------------------------------------
-- NoScript plugin for luakit                         --
-- (C) 2011 Mason Larobina <mason.larobina@gmail.com> --
--------------------------------------------------------

-- Get Lua environment
local os = require "os"
local tonumber = tonumber
local assert = assert
local table = table
local string = string

-- Get luakit environment
local webview = webview
local add_binds = add_binds
local lousy = require "lousy"
local sql_escape = lousy.util.sql_escape
local capi = { luakit = luakit, sqlite3 = sqlite3 }

module "noscript"

-- Default blocking values
enable_scripts = true
enable_plugins = true

create_table = [[
CREATE TABLE IF NOT EXISTS by_domain (
    id INTEGER PRIMARY KEY,
    domain TEXT,
    enable_scripts INTEGER,
    enable_plugins INTEGER
);]]

db = capi.sqlite3{ filename = capi.luakit.data_dir .. "/noscript.db" }
db:exec("PRAGMA synchronous = OFF; PRAGMA secure_delete = 1;")
db:exec(create_table)

local function btoi(bool) return bool and 1 or 0    end
local function itob(int)  return tonumber(int) ~= 0 end

local function get_domain(uri)
    uri = assert(lousy.uri.parse(uri), "invalid uri")
    return string.lower(uri.host)
end

local function match_domain(domain)
    local rows = db:exec(string.format("SELECT * FROM by_domain "
        .. "WHERE domain == %s;", sql_escape(domain)))
    if rows[1] then return rows[1] end
end

local function update(id, field, value)
    db:exec(string.format("UPDATE by_domain SET %s = %d WHERE id == %d;",
        field, btoi(value), id))
end

local function insert(domain, enable_scripts, enable_plugins)
    db:exec(string.format("INSERT INTO by_domain VALUES (NULL, %s, %d, %d);",
        sql_escape(domain), btoi(enable_scripts), btoi(enable_plugins)))
end

function webview.methods.toggle_scripts(view, w)
    local domain = get_domain(view.uri)
    local enable_scripts = _M.enable_scripts
    local row = match_domain(domain)

    if row then
        enable_scripts = itob(row.enable_scripts)
        update(row.id, "enable_scripts", not enable_scripts)
    else
        insert(domain, not enable_scripts, _M.enable_plugins)
    end

    w:notify(string.format("%sabled scripts for domain: %s",
        enable_scripts and "Dis" or "En", domain))
end

function webview.methods.toggle_plugins(view, w)
    local domain = get_domain(view.uri)
    local enable_plugins = _M.enable_plugins
    local row = match_domain(domain)

    if row then
        enable_plugins = itob(row.enable_plugins)
        update(row.id, "enable_plugins", not enable_plugins)
    else
        insert(domain, not _M.enable_scripts, enable_plugins)
    end

    w:notify(string.format("%sabled plugins for domain: %s",
        enable_plugins and "Dis" or "En", domain))
end

function webview.methods.toggle_remove(view, w)
    local domain = get_domain(view.uri)
    db:exec(string.format("DELETE FROM by_domain WHERE domain == %s;",
        sql_escape(domain)))
    w:notify("Removed rules for domain: " .. domain)
end

webview.init_funcs.noscript_load = function (view)
    view:add_signal("load-status", function (v, status)
        if status ~= "committed" or v.uri == "about:blank" then return end
        local enable_scripts, enable_plugins = _M.enable_scripts, _M.enable_plugins
        local domain = get_domain(v.uri)
        local row = match_domain(domain)
        if row then
            enable_scripts = itob(row.enable_scripts)
            enable_plugins = itob(row.enable_plugins)
        end
        view:set_property("enable-scripts", enable_scripts)
        view:set_property("enable-plugins", enable_plugins)
    end)
end

local buf = lousy.bind.buf
add_binds("normal", {
    buf("^,ts$", function (w) w:toggle_scripts() end),
    buf("^,tp$", function (w) w:toggle_plugins() end),
    buf("^,tr$", function (w) w:toggle_remove()  end),
})
