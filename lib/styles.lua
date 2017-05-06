--- User styles.
--
-- @module styles
-- @copyright 2016 Aidan Holm

local webview = require("webview")
local lousy   = require("lousy")
local lfs     = require("lfs")
local editor  = require("editor")
local globals = require("globals")
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
    local domains = { }
    while domain do
        domains[#domains + 1] = domain
        domain = string.match(domain, "%.(.+)")
    end
    return domains
end

local function update_stylesheet_application(view, domains, stylesheet, enabled)
    local match
    if stylesheet.when then
        for _, w in ipairs(stylesheet.when) do
            match = match or (w[1] == "url" and w[2] == view.uri)
            match = match or (w[1] == "url-prefix" and view.uri:find(w[2],1,true) == 1)
            match = match or (w[1] == "regexp" and w[2]:match(view.uri))

            if w[1] == "domain" then
                for _, domain in ipairs(domains) do
                    if w[2] == domain then match = true end
                end
            end
        end
    end
    view.stylesheets[stylesheet.ss] = match and enabled
end

local function update_stylesheet_applications(v)
    local domains = domains_from_uri(v.uri)
    local enabled = v:emit_signal("enable-styles")
    if enabled == nil then enabled = db_get(v.uri) ~= 0 end

    for _, s in ipairs(stylesheets or {}) do
        update_stylesheet_application(v, domains, s, enabled)
    end
end

webview.add_signal("init", function (view)
    view:add_signal("stylesheet", function (v)
        update_stylesheet_applications(v)
    end)
end)

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

local parse_moz_document_subrule = function (file)
    local word, param, i
    word, i = file:match("^%s+([%w-]+)%s*()")
    file = file:sub(i)
    param, i = file:match("(%b())()")
    file = file:sub(i)
    param = param:match("^%(['\"]?(.-)['\"]?%)$")
    return file, word, param
end

local parse_moz_document_section = function (file, parts)
    file = file:gsub("^%s*%@%-moz%-document", "")
    local when = {}
    local word, param

    while true do
        -- Strip off a subrule
        file, word, param = parse_moz_document_subrule(file)
        local valid_words = { url = true, ["url-prefix"] = true, domain = true, regexp = true }

        if valid_words[word] then
            if word == "regexp" then param = regex{pattern=param} end
            when[#when+1] = {word, param}
        else
            msg.warn("Ignoring unrecognized @-moz-document rule '%s'", word)
        end

        if file:match("^%s*,%s*") then
            file = file:sub(file:find(",")+1)
        else
            break
        end
    end
    local css, i = file:match("(%b{})()")
    css = css:sub(2, -2)
    file = file:sub(i)
    parts[#parts+1] = { when = when, css = css }

    return file
end

local parse_file = function (file)
    -- First, strip comments and @namespace
    file = file:gsub("%/%*.-%*%/","")
    file = file:gsub("%@namespace%s*url%b();?", "")
    -- Next, match moz document rules
    local parts = {}
    while file:find("^%s*%@%-moz%-document") do
        file = parse_moz_document_section(file, parts)
    end
    if file:find("%S") then
        parts[#parts+1] = { when = {"url-prefix", ""}, css = file }
    end
    return parts
end

local file_looks_like_old_format = function (source)
    local global_comment = "/* i really want this to be global */"
    return not source:find("@-moz-document",1,true) and not source:lower():find(global_comment)
end

--- Load the contents of a file as a stylesheet for a given domain.
-- @tparam string path The path of the file to load.
-- @tparam string domain The domain on which to apply the stylesheet.
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

--- Detect all files in the stylesheets directory and automatically load them.
_M.detect_files = function ()
    local cwd = lfs.currentdir()
    if not lfs.chdir(styles_dir) then
        msg.info(string.format("Stylesheet directory '%s' doesn't exist", styles_dir))
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

-- Warn about domain_props being broken
local domains = {}
for domain, prop in pairs(globals.domain_props) do
    if type(prop) == "table" and prop.user_stylesheet_uri then
        domains[#domains+1] = domain
    end
end

if #domains > 0 then
    msg.warn("Using domain_props for user stylesheets is non-functional")
    for _, domain in ipairs(domains) do
        msg.warn("Found user_stylesheet_uri property for domain '%s'", domain)
    end
    msg.warn("Instead, add an appropriately-named CSS file to %s", luakit.data_dir .. "/styles/")
    msg.warn("See https://github.com/aidanholm/luakit/issues/189")
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
