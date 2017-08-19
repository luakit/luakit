--- Centralized settings system.
--
-- The `settings` module provides a central place to access and modify settings
-- for all of luakit's modules.
--
-- @module settings
-- @author Aidan Holm
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local lousy = require("lousy")

local _M = {}

local settings_list = {}
local settings_groups

local S = {
    root = {}, -- Values for settings.foo
    domain = {}, -- Values for settings.on["domain"].foo
}

local function validate_settings_path (k)
    assert(type(k) == "string", "invalid settings path type: " .. type(k))
    local parts = lousy.util.string.split(k, "%.")
    assert(#parts >= 2, "settings path must have at least two sections")
    for _, part in ipairs(parts) do
        assert(part ~= "on" and part:match("^[%w_]+$"),
            "invalid settings path component '" .. k .."'")
    end
end

local function get_settings_path_type (k)
    if not settings_groups then
        settings_groups = {}
        for path in pairs(settings_list) do
            local parts = lousy.util.string.split(path, "%.")
            table.remove(parts)
            local gk
            for _, part in ipairs(parts) do
                gk = (gk and (gk..".") or "") .. part
                settings_groups[gk] = true
            end
        end
    end
    if settings_groups[k] then return "group" end
    if settings_list[k] then return "value" end
end

--- Register a table of settings.
-- Entries in the table of settings to register should be keyed by the setting
-- path string.
-- @tparam {[string]=table} settings The table of settings to register.
_M.register_settings = function (list)
    assert(type(list) == "table")

    -- Hack: certain tests rely on re-requiring modules, but registered settings
    -- aren't tied to the lifetime of a module, so prevent repeat-registers failing
    if package.loaded["tests.lib"] then
        for k in pairs(list) do settings_list[k] = nil end
    end

    for k, s in pairs(list) do
        validate_settings_path(k)
        assert(type(s) == "table", "setting '"..k.."' not a table")
        assert(not settings_list[k], "setting '"..k.."' already registered")
    end

    for k, s in pairs(list) do
        settings_list[k] = s
    end

    settings_groups = nil
end

local function S_get(section, k)
    local tree = not section and S.root or S.domain[section]
    if not tree then return nil end -- no rules for this domain
    return tree[k] or settings_list[k].default
end

local function S_set(section, k, v)
    if section then S.domain[section] = S.domain[section] or {} end
    local tree = not section and S.root or S.domain[section]
    tree[k] = v
end

local uri_domain_cache = {}

--- Retrieve the value of a setting for a URI, based on the setting's domain-specific values.
--
-- This does not take into account the non-domain-specific value _or_ the default
-- value for the setting.
--
-- The settings key must be a valid settings key.
-- @tparam string uri The URI.
-- @tparam string key The key of the setting to retrieve.
-- @return The value of the setting, or `nil` if no domain-specific value is set.
_M.get_setting_for_uri = function (uri, key)
    if uri ~= uri_domain_cache.uri then
        uri_domain_cache.uri = uri
        uri_domain_cache.domains = lousy.uri.domains_from_uri(uri)
        table.insert(uri_domain_cache.domains, "all")
    end
    local domains = uri_domain_cache.domains
    for _, domain in ipairs(domains) do
        local value = (S.domain[domain] or {})[key] -- S_get uses default
        if value then return value, domain end
    end
end

local new_settings_node

local function new_domain_node()
    local meta = { __metatable = false, subnodes = {} }
    meta.__index = function (_, k)
        if meta.subnodes[k] then return meta.subnodes[k] end
        assert(type(k) == "string" and #k > 0, "invalid domain name")
        meta.subnodes[k] = new_settings_node(nil, k)
        return meta.subnodes[k]
    end
    meta.__newindex = function ()
        error("cannot assign a value to a settings group")
    end
    return setmetatable({}, meta)
end

new_settings_node = function (prefix, section)
    local meta = { __metatable = false, subnodes = {}, section = section }

    if not prefix and not section then -- True root node generates on[] subnode
        meta.subnodes.on = new_domain_node()
    end

    meta.__index = function (_, k)
        if meta.subnodes[k] then return meta.subnodes[k] end
        local full_path = (prefix and (prefix..".") or "") .. k
        local type = get_settings_path_type(full_path)
        if type == "value" then return S_get(meta.section, full_path) end
        if type == "group" then
            meta.subnodes[k] = new_settings_node(full_path, meta.section)
            return meta.subnodes[k]
        end
    end
    meta.__newindex = function (_, k, v)
        local full_path = (prefix and (prefix..".") or "") .. k
        local type = get_settings_path_type(full_path)
        if type == "value" then
            S_set(meta.section, full_path, v)
        elseif type == "group" then
            error("cannot assign a value to a settings group")
        else
            error("cannot assign a value to invalid setting path '"..full_path.."'")
        end
    end
    return setmetatable({}, meta)
end

local root = new_settings_node()

return setmetatable(_M, { __index = root, __newindex = root })

-- vim: et:sw=4:ts=8:sts=4:tw=80
