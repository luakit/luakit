--- Dynamic proxy settings.
--
-- This module offers a simple and convenient user interface for using a proxy
-- while browsing the web. Users can add entries for specific proxy addresses,
-- and easily switch between using any of these proxies to redirect traffic. It
-- is also possible to use the system proxy, or disable proxy use altogether.
--
-- ### Adding a new proxy entry
--
-- To add a new proxy entry, use the `:proxy` command, with the name of the
-- proxy and the web address of the proxy as arguments:`:proxy <name> <address>`.
--
-- #### Example
--
-- To add a proxy entry for a local proxy running on port 8000, run the
-- following:
--
--     :proxy proxy-name socks://localhost:8000
--
-- ### Viewing and changing the current proxy
--
-- It is currently easiest to view the current proxy by opening the proxy menu
-- with the `:proxy` command. The current proxy will be shown in black text, while any
-- inactive proxies will be shown in light gray text.
--
-- @module proxy
-- @copyright Piotr Husiatyński <phusiatynski@gmail.com>

local lousy = require("lousy")
local theme = lousy.theme.get()
local window = require("window")
local binds = require("binds")
local new_mode = require("modes").new_mode
local add_binds, add_cmds = binds.add_binds, binds.add_cmds
local menu_binds = binds.menu_binds

local _, minor = luakit.webkit_version:match("^(%d+)%.(%d+)%.")
if tonumber(minor) < 16 then
    msg.error("proxy support in luakit requires WebKit2GTK 2.16 or later")
    msg.error("this version: %s", luakit.webkit_version)
    return {}
end

local _M = {}

--- Module global variables
local proxies_file = luakit.data_dir .. '/proxymenu'

local proxies = {}
local noproxy = { address = '' }
local active = noproxy

-- Helper function to update text in proxy indicator
local update_proxy_indicator = function (w)
    local name = _M.get_active().name
    local proxyi = w.sbar.r.proxyi
    if name then
        local text = string.format("[%s]", name)
        if proxyi.text ~= text then proxyi.text = text end
        proxyi:show()
    else
        proxyi:hide()
    end
end

local update_proxy_indicators = function ()
    for _, w in pairs(window.bywidget) do
        update_proxy_indicator(w)
    end
end

--- Get an ordered list of proxy names.
-- @treturn table List of proxy names.
function _M.get_names()
    return lousy.util.table.keys(proxies)
end

--- Get the address of proxy given by name.
-- @tparam string name The name of a proxy.
-- @treturn string The address of the proxy.
function _M.get(name)
    return proxies[name]
end

--- Get active proxy configuration
-- @treturn table The active proxy configuration. Two fields are present:
-- `name` and `address`.
function _M.get_active()
    return active
end

--- Load proxies list from file
-- @tparam string fd_name custom proxy storage or nil to use default
function _M.load(fd_name)
    fd_name = fd_name or proxies_file
    if not os.exists(fd_name) then return end
    local strip = lousy.util.string.strip

    for line in io.lines(fd_name) do
        local status, name, address = string.match(line, "^(.)%s(.+)%s(.+)$")
        if address then
            name, address = strip(name), strip(address)
            if status == '*' then
                active = { address = address, name = name }
            end
            proxies[name] = address
        end
    end

    if active and active.address ~= '' then
        soup.proxy_uri = active.address
        update_proxy_indicators()
    end
end

--- Save proxies list to file
-- @tparam string fd_name custom proxy storage or nil to use default
function _M.save(fd_name)
    local fd = io.open(fd_name or proxies_file, "w")
    for name, address in pairs(proxies) do
        if address ~= "" then
            local status = (active.name == name and '*') or ' '
            fd:write(string.format("%s %s %s\n", status, name, address))
        end
    end
    io.close(fd)
end

--- Add new proxy server to current list
-- @tparam string name proxy configuration name
-- @tparam string address proxy server address
-- @tparam boolean save_file do not save configuration if false
function _M.set(name, address, save_file)
    name = lousy.util.string.strip(name)
    if not string.match(name, "^([%w%p]+)$") then
        error("Invalid proxy name: " .. name)
    end
    proxies[name] = lousy.util.string.strip(address)
    if save_file ~= false then _M.save() end
end

--- Delete selected proxy from list
-- @tparam string name proxy server name
function _M.del(name)
    name = lousy.util.string.strip(name)
    if proxies[name] then
        -- if deleted proxy was the active one, turn proxy off
        if name == active.name then
            active = noproxy
        end
        proxies[name] = nil
        _M.save()
    end
end

--- Set given proxy to active. Return true on success, else false
-- @tparam string name proxy configuration name or nil to unset proxy.
function _M.set_active(name)
    if name then
        name = lousy.util.string.strip(name)
        if not proxies[name] then
            error("Unknown proxy: " .. name)
        end
        active = { name = name, address = proxies[name] }
    else
        active = noproxy
    end
    _M.save()
    return true
end

-- Create a proxy indicator widget and add it to the status bar
window.add_signal("init", function (w)
    local r = w.sbar.r
    r.proxyi = widget{type="label"}
    r.layout:pack(r.proxyi)
    r.layout:reorder(r.proxyi, 2)

    r.proxyi.fg = theme.proxyi_sbar_fg
    r.proxyi.font = theme.proxyi_sbar_font
    update_proxy_indicators()
end)

new_mode("proxymenu", {
    enter = function (w)
        local rows = {{ "Proxy Name", " Server address", title = true },
            {"  None",   "", address = "no_proxy", },
            {"  System", "", address = "default",  },}
        for _, name in ipairs(_M.get_names()) do
            local address = _M.get(name)
            table.insert(rows, {
                "  " .. name, " " .. address,
                name = name, address = lousy.util.escape(address),
            })
        end
        -- Color menu rows according to the currently used proxy
        local current_proxy = soup.proxy_uri
        local afg, ifg = theme.proxy_active_menu_fg, theme.proxy_inactive_menu_fg
        local abg, ibg = theme.proxy_active_menu_bg, theme.proxy_inactive_menu_bg
        for i=2,#rows do
            rows[i].fg = (rows[i].address == current_proxy) and afg or ifg
            rows[i].bg = (rows[i].address == current_proxy) and abg or ibg
        end

        w.menu:build(rows)
        w:notify("Use j/k to move, d delete, e edit, a add, Return activate.", false)
    end,

    leave = function (w)
        w.menu:hide()
    end,
})

local cmd = lousy.bind.cmd
add_cmds({
    cmd("proxy", "Change the current proxy or add a new proxy entry.",
        function (w, a)
            local params = lousy.util.string.split(a or '')
            if not a then
                w:set_mode("proxymenu")
            elseif #params == 2 then
                local name, address = unpack(params)
                _M.set(name, address)
            else
                w:error("Bad usage. Correct format :proxy or :proxy <name> <address>")
            end
        end),
})

local key = lousy.bind.key
add_binds("proxymenu", lousy.util.table.join({
    -- Select proxy
    key({}, "Return", "Use the currently highlighted proxy.",
        function (w)
            local row = w.menu:get()
            if row and row.address then
                _M.set_active(row.name)
                w:set_mode()
                soup.proxy_uri = row.address
                update_proxy_indicators()
                if row.name then
                    w:notify(string.format("Using proxy: %s (%s)", row.name, row.address))
                elseif row.address == "default" then
                    w:notify("Using system default proxy.")
                else
                    w:notify("Unset proxy.")
                end
            end
        end),

    -- Delete proxy
    key({}, "d", "Delete the currently highlighted proxy entry.",
        function (w)
            local row = w.menu:get()
            if row and row.name then
                _M.del(row.name)
                w.menu:del()
            end
        end),

    -- Edit proxy
    key({}, "e", "Edit the currently highlighted proxy entry.",
        function (w)
            local row = w.menu:get()
            if row and row.name then
                w:enter_cmd(string.format(":proxy %s %s", row.name, row.address))
            end
        end),

    -- New proxy
    key({}, "a", "Begin adding a new proxy entry.",
        function (w) w:enter_cmd(":proxy ") end),
}, menu_binds))

-- Initialize module
_M.load()

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
