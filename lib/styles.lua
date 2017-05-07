--- User styles.
--
-- @module styles
-- @copyright 2016 Aidan Holm

local window = require("window")
local webview = require("webview")
local lousy   = require("lousy")
local lfs     = require("lfs")
local editor  = require("editor")
local globals = require("globals")
local binds = require("binds")
local new_mode = require("modes").new_mode
local add_binds, add_cmds = binds.add_binds, binds.add_cmds
local menu_binds = binds.menu_binds
local key     = lousy.bind.key

local capi = {
    luakit = luakit,
    sqlite3 = sqlite3
}

local _M = {}

local styles_dir = capi.luakit.data_dir .. "/styles/"

local default_enabled = 1

local stylesheets
local stylesheets_menu_rows = setmetatable({}, { __mode = "k" })

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

local function domain_from_uri(uri)
    if not uri or uri == "" then return nil end
    uri = assert(lousy.uri.parse(uri), "invalid uri")
    -- Return the scheme for non-http/https URIs
    if uri.scheme ~= "http" and uri.scheme ~= "https" then
        return uri.scheme
    else
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

local function update_stylesheet_application(view, domains, stylesheet)
    for _, part in ipairs(stylesheet.parts) do
        local match = false
        for _, w in ipairs(part.when) do
            match = match or (w[1] == "url" and w[2] == view.uri)
            match = match or (w[1] == "url-prefix" and view.uri:find(w[2],1,true) == 1)
            match = match or (w[1] == "regexp" and w[2]:match(view.uri))
            if w[1] == "domain" then
                for _, domain in ipairs(domains) do
                    match = match or (w[2] == domain)
                end
            end
        end
        match = match and stylesheet.enabled
        view.stylesheets[part.ss] = match
    end
end

local function update_stylesheet_applications(v)
    local domains = domains_from_uri(v.uri)
    local enabled = v:emit_signal("enable-styles")
    if enabled == nil then enabled = db_get(v.uri) ~= 0 end

    for _, s in ipairs(stylesheets or {}) do
        update_stylesheet_application(v, domains, s)
    end
end

local menu_row_for_stylesheet = function (stylesheet)
    local theme = lousy.theme.get()
    local title = stylesheet.file
    local state = stylesheet.enabled and "Enabled" or "Disabled"
    local fg = stylesheet.enabled and theme.menu_enabled_fg or theme.menu_disabled_fg
    local bg = stylesheet.enabled and theme.menu_enabled_bg or theme.menu_disabled_bg
    return { title, state, stylesheet = stylesheet, fg = fg, bg = bg }
end

local function update_stylesheet_menus()
    -- Update any windows in styles-list mode
    for _, w in pairs(window.bywidget) do
        if w:is_mode("styles-list") then
            assert(stylesheets_menu_rows[w])
            local rows = stylesheets_menu_rows[w]
            for i, stylesheet in ipairs(stylesheets) do
                local rep = menu_row_for_stylesheet(stylesheet)
                for j in ipairs(rep) do
                    rows[i+1][j] = rep[j]
                end
                rows[i+1].fg = rep.fg
                rows[i+1].bg = rep.bg
            end
            w.menu:update()
        end
    end
end

local function update_all_stylesheet_applications()
    -- Update page appearances
    for _, ww in pairs(window.bywidget) do
        for _, v in pairs(ww.tabs.children) do
            update_stylesheet_applications(v)
        end
    end
    update_stylesheet_menus()
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
    update_all_stylesheet_applications()
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

local global_comment = "/* i really want this to be global */"
local file_looks_like_old_format = function (source)
    return not source:find("@-moz-document",1,true) and not source:lower():find(global_comment)
end

--- Load the contents of a file as a stylesheet for a given domain.
-- @tparam string path The path of the file to load.
_M.load_file = function (path)
    if stylesheet == nil then return end

    local file = io.open(path, "r")
    local source = file:read("*all")
    file:close()

    if file_looks_like_old_format(source) then
        msg.error("Not loading stylesheet '%s'", path)
        return true
    end

    local parsed = parse_file(source)

    local parts = {}
    for _, part in ipairs(parsed) do
        table.insert(parts, {
            ss = stylesheet{ source = part.css },
            when = part.when
        })
    end
    stylesheets[#stylesheets+1] = {
        idx = #stylesheets+1, -- index of this stylesheet
        parts = parts,
        file = path,
        enabled = true, -- TODO: Load from DB
    }
end

--- Detect all files in the stylesheets directory and automatically load them.
_M.detect_files = function ()
    local cwd = lfs.currentdir()
    if not lfs.chdir(styles_dir) then
        msg.info(string.format("Stylesheet directory '%s' doesn't exist", styles_dir))
        return
    end

    for _, stylesheet in pairs(stylesheets or {}) do
        for _, part in ipairs(stylesheet.parts) do
            part.ss.source = ""
        end
    end
    stylesheets = {}

    local old_stylesheets
    for filename in lfs.dir(styles_dir) do
        if string.find(filename, ".css$") then
            old_stylesheets = _M.load_file(filename) or old_stylesheets
        end
    end

    update_all_stylesheet_applications()

    if old_stylesheets then
        msg.error([[Outdated stylesheet format detected!

Some stylesheets appear to be using the old stylesheet system: no
@-moz-document rules were found. If this file is intended to be global
(applying to all pages, including luakit:// pages), add the CSS comment

    %s

anywhere to the file (case-insensitive).

This mechanism is to prevent parsing old stylesheets as new ones; the
unexpected interaction of many stylesheets on websites tends to have
strange effects.

To automatically upgrade your files, you can run :styles-rewrite-old-files
This command wraps the contents of the file in a @-moz-document domain()
block, with the domain based on the filename. A backup file is created.

]], global_comment)
    end

    lfs.chdir(cwd)
end

local rewrite_file_format = function ()
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
                domain = string.sub(domain, 2)
            end
            -- Get source
            local file = assert(io.open(filename, "r"))
            local source = file:read("*all")
            file:close()

            if file_looks_like_old_format(source) then
                assert(os.rename(filename, filename .. ".backup"))
                msg.info("Rewriting CSS file '%s'", filename)
                local new_source = ('@-moz-document domain("%s") {\n\n%s\n}\n'):format(domain, source)
                local new_file = assert(io.open(filename, "w"))
                new_file:write(new_source)
                new_file:close()
            end
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
    cmd({"styles-rewrite-old-files"}, "Rewrite user stylesheets using old format.", function (w)
        w:notify("styles: Rewriting files...")
        rewrite_file_format()
        w:notify("styles: Rewriting files complete.")
    end),
    cmd({"styles-list"}, "List installed userstyles.",
        function (w) w:set_mode("styles-list") end),
})

-- Add mode to display all userscripts in menu
new_mode("styles-list", {
    enter = function (w)
        local rows = {{ "Stylesheets", "State", title = true }}
        for _, stylesheet in ipairs(stylesheets) do
            table.insert(rows, menu_row_for_stylesheet(stylesheet))
        end
        if #rows == 1 then
            w:notify("No userstyles installed.")
            return
        end
        stylesheets_menu_rows[w] = rows
        w.menu:build(rows)
        w:notify("Use j/k to move, <space> to enable/disable.", false)
    end,

    leave = function (w)
        stylesheets_menu_rows[w] = nil
        w.menu:hide()
    end,
})

add_binds("styles-list", lousy.util.table.join({
    -- Delete userscript
    key({}, "space", "Enable/disable the currently highlighted userstyle.",
        function (w)
        local row = w.menu:get()
        if row and row.stylesheet then
            row.stylesheet.enabled = not row.stylesheet.enabled
            update_all_stylesheet_applications()
        end
    end),
}, menu_binds))

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
