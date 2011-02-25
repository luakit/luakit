--------------------------------------------------------------
-- Dynamic proxy settings                                   --
-- @author Piotr Husiatyński &lt;phusiatynski@gmail.com&gt; --
--------------------------------------------------------------

-- Grab environment we need
local io = io
local os = os
local pairs = pairs
local ipairs = ipairs
local error = error
local string = string
local lousy = require "lousy"
local theme = theme
local unpack = unpack
local table = table
local capi = { luakit = luakit, soup = soup }
local webview = webview
local widget = widget
local window = window
-- Check for mode/bind functions
local add_binds, add_cmds = add_binds, add_cmds
local new_mode, menu_binds = new_mode, menu_binds

module("proxy")

--- Module global variables
local proxies_file = capi.luakit.data_dir .. '/proxymenu'

local proxies = {}
local noproxy = { address = '' }
local active = noproxy

-- Return ordered list of proxy names
function get_names()
    return lousy.util.table.keys(proxies)
end

-- Return address of proxy given by name
function get(name)
    return proxies[name]
end

--- Get active proxy configuration: { name = "name", address = "address" }
function get_active()
    return active
end

--- Load proxies list from file
-- @param fd_name custom proxy storage of nil to use default
function load(fd_name)
    local fd_name = fd_name or proxies_file
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
end

--- Save proxies list to file
-- @param fd_name custom proxy storage of nil to use default
function save(fd_name)
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
-- @param name proxy configuration name
-- @param address proxy server address
-- @param save_file do not save configuration if false
function set(name, address, save_file)
    local name = lousy.util.string.strip(name)
    if not string.match(name, "^([%w%p]+)$") then
        error("Invalid proxy name: " .. name)
    end
    proxies[name] = lousy.util.string.strip(address)
    if save_file ~= false then save() end
end

--- Delete selected proxy from list
-- @param name proxy server name
function del(name)
    local name = lousy.util.string.strip(name)
    if proxies[name] then
        -- if deleted proxy was the active one, turn proxy off
        if name == active.name then
            active = noproxy
        end
        proxies[name] = nil
        save()
    end
end

--- Set given proxy to active. Return true on success, else false
-- @param name proxy configuration name or nil to unset proxy.
function set_active(name)
    if name then
        local name = lousy.util.string.strip(name)
        if not proxies[name] then
            error("Unknown proxy: " .. name)
        end
        active = { name = name, address = proxies[name] }
    else
        active = noproxy
    end
    save()
    return true
end

-- Load the initial proxy address
webview.init_funcs.set_proxy = function (view, w)
    local active = get_active()
    if active and active.address ~= '' then
        capi.soup.set_property('proxy-uri', active.address)
    end
    -- The proxy property is set globablly so this function only needs to be
    -- called once. Other proxy changes take place from the interactive
    -- `:proxy` menu.
    webview.init_funcs.set_proxy = nil
end

-- Create a proxy indicator widget and add it to the status bar
window.init_funcs.build_proxy_indicator = function (w)
    local r = w.sbar.r
    r.proxyi = widget{type="label"}
    r.layout:pack_start(r.proxyi, false, false, 0)
    r.layout:reorder(r.proxyi, 2)

    r.proxyi.fg = theme.proxyi_sbar_fg
    r.proxyi.font = theme.proxyi_sbar_font
    w:update_proxy_indicator()
end

-- Helper function to update text in proxy indicator
window.methods.update_proxy_indicator = function (w)
    local name = get_active().name
    local proxyi = w.sbar.r.proxyi
    if name then
        local text = string.format("[%s]", name)
        if proxyi.text ~= text then proxyi.text = text end
        proxyi:show()
    else
        proxyi:hide()
    end
end

-- Update proxy indicator in status bar on change of address
webview.init_funcs.proxy_indicator_update = function (view, w)
    view:add_signal("property::proxy-uri", function (v)
        w:update_proxy_indicator()
    end)
end

new_mode("proxymenu", {
    enter = function (w)
        local afg, ifg = theme.proxy_active_menu_fg, theme.proxy_inactive_menu_fg
        local abg, ibg = theme.proxy_active_menu_bg, theme.proxy_inactive_menu_bg
        local a = get_active()
        local rows = {{ "Proxy Name", " Server address", title = true },
            {"  None", "", address = '',
                fg = (a.address == '' and afg) or ifg,
                bg = (a.address == '' and abg) or ibg},}
        for _, name in ipairs(get_names()) do
            local address = get(name)
            table.insert(rows, {
                "  " .. name, " " .. address,
                name = name, address = lousy.util.escape(address),
                fg = (a.name == name and afg) or ifg,
                bg = (a.name == name and abg) or ibg,
            })
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
    cmd("proxy",
        function (w, a)
            local params = lousy.util.string.split(a or '')
            if not a then
                w:set_mode("proxymenu")
            elseif #params == 2 then
                local name, address = unpack(params)
                set(name, address)
            else
                w:error("Bad usage. Correct format :proxy <name> <address>")
            end
        end),
})

local key = lousy.bind.key
add_binds("proxymenu", lousy.util.table.join({
    -- Select proxy
    key({}, "Return",
        function (w)
            local row = w.menu:get()
            if row and row.address then
                set_active(row.name)
                w:set_mode()
                capi.soup.set_property('proxy-uri', row.address)
                if row.name then
                    w:notify(string.format("Using proxy: %s (%s)", row.name, row.address))
                else
                    w:notify("Unset proxy.")
                end
            end
        end),

    -- Delete proxy
    key({}, "d",
        function (w)
            local row = w.menu:get()
            if row and row.name then
                del(row.name)
                w.menu:del()
            end
        end),

    -- Edit proxy
    key({}, "e",
        function (w)
            local row = w.menu:get()
            if row and row.name then
                w:enter_cmd(string.format(":proxy %s %s", row.name, row.address))
            end
        end),

    -- New proxy
    key({}, "a", function (w) w:enter_cmd(":proxy ") end),

    -- Exit menu
    key({}, "q", function (w) w:set_mode() end),

}, menu_binds))

-- Initialize module
load()
