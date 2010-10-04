----------------------------------------------------------------
-- Dynamic proxy settings                                     --
-- @author Piotr Husiatyński &lt;phusiatynski@gmail.com&gt;   --
----------------------------------------------------------------


local io = io
local os = os
local pairs = pairs
local string = string

local lousy = {
    util=require('lousy.util')
}
local capi = {luakit=luakit}

module("proxy")

local proxies
local proxies_file = capi.luakit.data_dir .. '/proxy'
local noproxy = {name="NoProxy"}
local active = noproxy


--- Initialize proxy plugin
function init()
    load()
end

--- Load proxies list from file
-- @param fd_name custom proxy storage of nil to use default
function load(fd_name)
    local fd_name = fd_name or proxies_file
    proxies = proxies or noproxy

    if not os.exists(fd_name) then
        return
    end

    for line in io.lines(fd_name) do
        local status, name, address = string.match(
                line, "^(.)%s(.-)%s(.+)$")
        if name then
            if status == 'a' then
                active = {address=address, name=name}
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
        local status = active.address == address and 'a' or ' '
        fd:write(string.format("%s %s %s\n", status, name, address))
    end
    io.close(fd)
end

--- Return list of defined proxy servers
function get_list()
    return proxies
end

--- Add new proxy server to current list
-- @param name proxy configuration name
-- @param address proxy server address
-- @param save_file do not save configuration if false
function add(name, address, save_file)
    local name = lousy.util.string.strip(name)
    proxies[name] = lousy.util.string.strip(address)
    if save_file ~= false then
        save()
    end
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
-- @param name proxy configuration name
function set_active(name)
    local name = lousy.util.string.strip(name)
    if not proxies[name] then
        return false
    end
    active = {name=name, address=proxies[name]}
    save()
    return true
end

--- Get active proxy configuration: {name="name", address="address"}
function get_active()
    return active
end

-- Initialize module
init()
