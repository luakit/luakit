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
    view_overrides = setmetatable({}, { __mode = "k" }),
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

    local meta = settings_list[k]
    if meta.type == "enum" then
        if not meta.options[v] then
            local opts = table.concat(lousy.util.table.keys(meta.options), ", ")
            error(string.format("Wrong type for setting '%s': expected one of %s",
                k, opts))
        end
    elseif meta.type and type(v) ~= meta.type then
        error(string.format("Wrong type for setting '%s': expected %s, got %s",
            k, meta.type, type(v)))
    end
    if meta.type == "number" then
        if (meta.min and v < meta.min) or (meta.max and v > meta.max) then
            local range = "[" .. tostring(meta.min or "") .. ".." .. tostring(meta.max or "") .. "]"
            error(string.format("Value outside accepted range %s for setting '%s': %s", range, k))
        end
    end
    if meta.validator and not meta.validator(v) then
        error(string.format("Invalid value for setting '%s'", k))
    end

    tree[k] = v
end

local function S_get_table(section, k)
    local tbl = S_get(section, k)
    return setmetatable({}, {
        __index = tbl,
        __newindex = tbl,
        __metatable = false,
    })
end

local function S_set_table(section, k, v)
    local tbl = {}
    if section then S.domain[section] = S.domain[section] or {} end
    local tree = not section and S.root or S.domain[section]
    tree[k] = tbl
    -- TODO: add validation for tables
    for kk, vv in pairs(v) do tbl[kk] = vv end
end

--- Retrieve the value of a setting for a webview.
--
-- This function considers, in order:
--
-- 1. any view-specific overrides
-- 2. the setting's domain-specific values
-- 3. the setting's non-domain-specific value
-- 4. the setting's default value
--
-- The settings key must be a valid settings key.
-- @tparam widget view The webview.
-- @tparam string key The key of the setting to retrieve.
-- @return The value of the setting.
_M.get_setting_for_view = function (view, key)
    assert(type(view) == "widget" and view.type == "webview")
    local tree = S.view_overrides[view]
    if tree and tree[key] then return tree[key] end
    local val = _M.get_setting_for_uri(view.uri, key)
    if val then return val end
    return _M.get_setting(key)
end

--- Add or remove a view-specific override for a setting.
-- Passing `nil` as the `value` will clear any override.
--
-- The settings key must be a valid settings key.
-- @tparam widget view The webview.
-- @tparam string key The key of the setting to override.
-- @return The new value of the setting override.
_M.override_setting_for_view = function (view, key, value)
    assert(type(view) == "widget" and view.type == "webview")
    local vo = S.view_overrides
    vo[view] = vo[view] or {}
    vo[view][key] = value
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

--- Retrieve the value of a setting, whether it's explicitly set or the default.
--
-- This does not take into account any domain-specific values.
--
-- The settings key must be a valid settings key.
-- @tparam string key The key of the setting to retrieve.
-- @return The value of the setting.
_M.get_setting = function (key)
    return S_get(nil, key)
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
        if type == "value" then
            local getter = (settings_list[full_path].type == "table") and S_get_table or S_get
            return (getter)(meta.section, full_path)
        end
        if type == "group" then
            meta.subnodes[k] = new_settings_node(full_path, meta.section)
            return meta.subnodes[k]
        end
    end
    meta.__newindex = function (_, k, v)
        local full_path = (prefix and (prefix..".") or "") .. k
        local type = get_settings_path_type(full_path)
        if type == "value" then
            local setter = (settings_list[full_path].type == "table") and S_set_table or S_set
            setter(meta.section, full_path, v)
        elseif type == "group" then
            error("cannot assign a value to a settings group")
        else
            error("cannot assign a value to invalid setting path '"..full_path.."'")
        end
    end
    return setmetatable({}, meta)
end

local migration_warnings = {}

--- Migration helper function.
-- @deprecated should be used only for existing code.
_M.add_migration_warning = function (k, v)
    if #migration_warnings == 0 then
        table.insert(migration_warnings, "Globals.lua is deprecated, and will be removed in the next release!")
        table.insert(migration_warnings, "To migrate, add the following to your rc.lua:")
        table.insert(migration_warnings, "")
        luakit.idle_add(function ()
            table.insert(migration_warnings, "")
            table.insert(migration_warnings, "Warnings have only been printed for settings with non-default values")
            msg.warn("%s", table.concat(migration_warnings, "\n"))
        end)
    end
    if type(v) == "string" then v = string.format("%q", v) end
    table.insert(migration_warnings, string.format("  settings.%s = %s", k, v))
end

--- Migration helper function.
-- @deprecated should be used only for existing code.
_M.migrate_global = function (sk, gk)
    local globals = package.loaded.globals or {}
    if globals[gk] and (globals[gk] ~= settings_list[sk].default) then
        _M.add_migration_warning(sk, globals[gk])
        S_set(nil, sk, globals[gk])
    end
end

root = new_settings_node()

return setmetatable(_M, { __index = root, __newindex = root })

-- vim: et:sw=4:ts=8:sts=4:tw=80
