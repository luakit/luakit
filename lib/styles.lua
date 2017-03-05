--- User styles.
--
-- @module styles
-- @copyright 2016 Aidan Holm

local webview = require("webview")
local lousy   = require("lousy")
local lfs     = require("lfs")
local editor  = require("editor")
local binds = require("binds")
local add_binds, add_cmds = binds.add_binds, binds.add_cmds
local key     = lousy.bind.key

local capi = {
	luakit = luakit,
	sqlite3 = sqlite3 
}

local _M = {}

local styles_dir = capi.luakit.data_dir .. "/styles/"

local default_enabled = 1

local stylesheets = {}

local db = capi.sqlite3{ filename = capi.luakit.data_dir .. "/styles.db" }
db:exec("PRAGMA synchronous = OFF; PRAGMA secure_delete = 1;")

local query_create = db:compile [[
	CREATE TABLE IF NOT EXISTS by_domain (
		id INTEGER PRIMARY KEY,
		domain TEXT,
		enabled INTEGER
	);]]

query_create:exec()

local query_insert = db:compile [[ INSERT INTO by_domain VALUES (NULL, ?, ?) ]]
local query_update = db:compile [[ UPDATE by_domain SET enabled = ? WHERE id == ?  ]]
local query_select = db:compile [[ SELECT * FROM by_domain WHERE domain == ?  ]]

local function string_starts(str, prefix)
   return string.sub(str, 1, string.len(prefix)) == prefix
end

local function domain_from_uri(uri)
	if not uri then
		return nil
	elseif uri == "about:blank" then
		return "about:blank"
	elseif string_starts(uri, "file://") then
		return "file"
	else
		uri = assert(lousy.uri.parse(uri), "invalid uri")
		return string.lower(uri.host)
	end
end

local function db_get(uri)
	local domain = domain_from_uri(uri)
	if not domain then
		return default_enabled
	else
		local rows = query_select:exec{domain}
		return rows[1] and rows[1].enabled or default_enabled
	end
end

local function db_set(uri, enabled)
	local domain = domain_from_uri(uri)
    local rows = query_select:exec{domain}
	if rows[1] then
		query_update:exec{enabled, rows[1].id}
	else
		query_insert:exec{domain, enabled}
	end
end

local function domains_from_uri(uri)
    local domain = domain_from_uri(uri)
    local domains = { domain }
    while domain do
        domains[#domains + 1] = "." .. domain
        domain = string.match(domain, "%.(.+)")
    end
    return domains
end

webview.init_funcs.styles_load = function(view)
    view:add_signal("stylesheet", function (v)
        local domains = domains_from_uri(v.uri)
        domains[#domains + 1] = "all"
        local enabled = v:emit_signal("enable-styles")
        if enabled == nil then enabled = db_get(v.uri) ~= 0 end

        for k, s in pairs(stylesheets) do
            local match
            for _, domain in ipairs(domains) do
                if k == domain then match = domain end
            end
            v.stylesheets[s] = match ~= nil and enabled
        end
    end)
end

function webview.methods.styles_enabled_get(view, _)
	return db_get(view.uri) == 1 and true or false
end

function webview.methods.styles_enabled_set(view, _, enabled)
	db_set(view.uri, enabled and 1 or 0)
end

function webview.methods.styles_toggle(view, _)
	local enabled = 1 - db_get(view.uri)
	db_set(view.uri, enabled)
end

_M.load_file = function (path, domain)
    if stylesheet == nil then return end

    local file = io.open(path, "r")
    local source = file:read("*all")
    file:close()

    if stylesheets[domain] then
        stylesheets[domain].source = source
    else
        stylesheets[domain] = stylesheet{ source = source }
    end
end

_M.detect_files = function ()
    local cwd = lfs.currentdir()
    if not lfs.chdir(styles_dir) then
		print(string.format("Stylesheet directory '%s' doesn't exist, not loading user styles...", styles_dir))
		return
	end
	for filename in lfs.dir(styles_dir) do
		if string.find(filename, ".css$") then
			-- Get the domain name from the filename
			local domain = string.sub(filename, 1, #filename - 4)
			if string.sub(domain, 1, 1) == "*" then
				domain = "." .. string.sub(domain, 2)
			end
            _M.load_file(filename, domain)
		end
    end
    lfs.chdir(cwd)
end

local cmd = lousy.bind.cmd
add_cmds({
    cmd({"styles-reload", "sr"}, "Reload user stylesheets.", function (w)
        w:notify("styles: Reloading files...")
        _M.detect_files()
        w:notify("styles: Reloading files complete.")
    end),
})

add_binds("normal", {
    key({}, "V", "Edit page user stylesheet.", function (w)
		if string.sub(w.view.uri, 1, 9) == "luakit://" then return end
		local domain = domain_from_uri(w.view.uri)
		local file = capi.luakit.data_dir .. "/styles/" .. domain .. ".css"
		editor.edit(file)
	end),
})

_M.detect_files()

return _M
