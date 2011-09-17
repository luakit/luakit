-------------------------------------------------------
-- Auto save/apply zoom levels on a per-domain basis --
-- © 2011 Roman Leonov   <rliaonau@gmail.com>        --
-- © 2011 Mason Larobina <mason.larobina@gmail.com>  --
-------------------------------------------------------

local print = print
-- Get lua environment
local math         = require "math"
local string       = string
local assert       = assert
local tostring     = tostring
local setmetatable = setmetatable

-- Get luakit environment
local lousy   = require "lousy"
local webview = webview
local window  = window
local widget  = widget
local theme   = theme
local capi    = { luakit = luakit, sqlite3 = sqlite3 }

module "autozoom"

local defaults = {
    level        = 1.0,
    full_content = false,
    visible      = "non-default",
    text         = "zoom:{level}%",
}
setmetatable(_M, {__index = _M.defaults})

-- Open database
local db = capi.sqlite3{ filename = capi.luakit.data_dir .. "/autozoom.db" }
db:exec("PRAGMA synchronous = OFF;")
-- Create table
db:exec([[
CREATE TABLE IF NOT EXISTS by_domain (
    domain TEXT PRIMARY KEY,
    level FLOAT,
    full_content INTEGER
);
]])

-- Simple round function for lua-users wiki
local function round(num)
    local mult = 100
    return math.floor(num * mult + 0.5) / mult
end

local function get_domain(uri)
    local domain = assert(lousy.uri.parse(uri), "invalid uri").host
    return lousy.util.sql_escape(string.match(domain, "^www%.(.+)") or domain)
end

function set(uri, level, full_content)
    local query_insert = [[INSERT OR REPLACE INTO by_domain
    (domain, level, full_content)
    VALUES(%s, %f, %d);]]
    db:exec(string.format(query_insert, get_domain(uri), level or defaults.level,
        full_content and 1 or 0))
end

function unset(uri)
    local query_delete = [[DELETE FROM by_domain WHERE domain=%s;]]
    db:exec(string.format(query_delete, get_domain(uri)))
end

function clear(uri) db:exec([[DELETE * FROM by_domain;]]) end

function get(uri)
    local query_obtain = [[SELECT * FROM by_domain WHERE domain=%s;]]
    local ret = db:exec(string.format(query_obtain, get_domain(uri)))
    if ret and ret[1] then
        return ret[1].level, (ret[1].full_content == "1")
    end
    return defaults.level, defaults.full_content
end

local function is_default(level, full_content)
    return ((level == defaults.level) and (full_content == defaults.full_content))
end

local function get_zoom(v)
    return  round(v:get_property("zoom-level")), v:get_property("full-content-zoom")
end

local function set_zoom(v, level, full_content)
    v:set_property("zoom-level", level)
    v:set_property("full-content-zoom", full_content)
end

window.init_funcs.notebook_signals_autoozoom = function (w)
    w.tabs:add_signal("switch-page", function (nbook, view, idx)
        capi.luakit.idle_add(function ()
            w:update_zoom()
            return false
        end)
    end)
end

window.init_funcs.create_zoom_label = function (w)
    local sbar = w.sbar.l
    sbar.zoom = widget({ type = "label" })
    sbar.layout:pack_start(sbar.zoom, false, false, 0)
    sbar.layout:reorder(sbar.zoom, 0)
    sbar.zoom.fg = theme.zoom_sbar_fg
    sbar.zoom.font = theme.zoom_sbar_font
end

window.methods.update_zoom = function (w)
    local zoom = w.sbar.l.zoom
    local level, full_content = get_zoom(w.view)
    local visible = defaults.visible
    if (visible == "non-default") and is_default(level, full_content) then
        visible = false
    end
    if w.view and visible then
        local text = string.gsub(defaults.text, "{([%w_]+)}",
            { level = 100 * level, full_content = tostring(full_content) })
        if zoom.text ~= text then zoom.text = text end
        zoom:show()
    else
        zoom:hide()
    end
end

webview.init_funcs.autozoom_setup = function (view, w)
    local function update(v)
        local level, full_content = get_zoom(v)
        print("updating:")
        if is_default(level, full_content) then
        print("unsetting")
            unset(v.uri)
        else
        print("setting level = "..level..", content = "..tostring(full_content))
            set(v.uri, level, full_content)
        end
        w:update_zoom()
    end
    local function start_watch()
        view:add_signal("property::zoom-level",        update)
        view:add_signal("property::full-content-zoom", update)
    end
    local function stop_watch()
        view:remove_signal("property::zoom-level",        update)
        view:remove_signal("property::full-content-zoom", update)
    end
    start_watch()
    -- Load zoom changes
    view:add_signal("load-status", function (view, status)
        if status ~= "first-visual" then return end
        stop_watch()
        set_zoom(view, get(view.uri))
        start_watch()
    end)
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
