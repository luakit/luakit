--------------------------------------------------------------
-- Dynamic proxy settings                                   --
-- @author Piotr Husiatyński &lt;phusiatynski@gmail.com&gt; --
--------------------------------------------------------------

local io = io
local os = os
local pairs = pairs
local error = error
local string = string
local util = require "lousy.util"
local capi = { luakit = luakit }
local webview = webview

module("proxy")

--- Module global variables
local proxies_file = capi.luakit.data_dir .. '/proxylist'

local proxies = {}
local noproxy = { address = '' }
local active = noproxy

-- Return ordered list of proxy names
function get_names()
    return util.table.keys(proxies)
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
    local strip = util.string.strip

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
    local name = util.string.strip(name)
    if not string.match(name, "^([%w%p]+)$") then
        error("Invalid proxy name: " .. name)
    end
    proxies[name] = util.string.strip(address)
    if save_file ~= false then save() end
end

--- Delete selected proxy from list
-- @param name proxy server name
function del(name)
    local name = util.string.strip(name)
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
        local name = util.string.strip(name)
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
        view:set_prop('proxy-uri', active.address)
    end
    -- The proxy property is a global setting so no need to call this again.
    webview.init_funcs.set_proxy = nil
end

-- Initialize module
load()
