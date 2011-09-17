-------------------------------------------------------
-- Auto save/apply zoom levels on a per-domain basis --
-- © 2011 Roman Leonov   <rliaonau@gmail.com>        --
-- © 2011 Mason Larobina <mason.larobina@gmail.com>  --
-------------------------------------------------------

-- Get lua environment
local math     = require "math"
local tonumber = tonumber
local string   = string
local assert   = assert
local tostring = tostring

-- Get luakit environment
local lousy   = require "lousy"
local webview = webview
local window  = window
local widget  = widget
local theme   = theme
local capi    = { luakit = luakit, sqlite3 = sqlite3 }

module "autozoom"

defaults = {
    level        = 1.0,
    full_content = false,
    visible      = "non-default",
    text         = "zoom:{level}%",
}

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
local function round(num, idp)
    local mult = 10^(idp or 0)
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
    db:exec(string.format(query_insert, get_domain(uri), round(level, 6),
        full_content and 1 or 0))
end

function unset(uri)
    local query_delete = [[DELETE FROM by_domain WHERE domain=%s;]]
    db:exec(string.format(query_delete, get_domain(uri)))
end

function get(uri)
    local query_obtain = [[SELECT * FROM by_domain WHERE domain=%s;]]
    return db:exec(string.format(query_obtain, get_domain(uri)))
end

local function get_zoom(v)
    return  round(v:get_property("zoom-level"), 6), v:get_property("full-content-zoom")
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
    if (visible == "non-default") and
           (level == defaults.level)  and
           (full_content == defaults.full_content) then
        visible = false
    elseif (string.match(string.lower(tostring(visible)), "false") ) then
        visible = false
    end
    if w.view and visible then
        local text = string.gsub(defaults.text, "{(%w+)}",
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
        if (level == defaults.level) and (full_content == defaults.full_content) then
            unset(v.uri)
        else
            set(v.uri, level, full_content)
        end
        w:update_zoom()
    end
    -- Watch zoom changes
    view:add_signal("property::zoom-level",        function (v) update(v) end)
    view:add_signal("property::full-content-zoom", function (v) update(v) end)
    -- Load zoom changes
    view:add_signal("load-status", function (view, status)
        if status ~= "first-visual" then return end
        local ret = get(view.uri)
        if ret and ret[1] then
            view:set_property("zoom-level", tonumber(ret[1].level))
            view:set_property("full-content-zoom", ret[1].full_content == "1")
        else
            view:set_property("zoom-level", defaults.level)
            view:set_property("full-content-zoom", defaults.full_content)
        end
    end)
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
