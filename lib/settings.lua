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

local function validate_settings_path (k)
    assert(type(k) == "string", "invalid settings path type: " .. type(k))
    local parts = lousy.util.string.split(k, "%.")
    assert(#parts >= 2, "settings path must have at least two sections")
    for _, part in ipairs(parts) do
        assert(part:match("^[%w_]+$"), "invalid settings path component '" .. k .."'")
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
        settings_list[k] = {
            meta = s,
            value = s.default,
        }
    end

    settings_groups = nil
end

local function new_settings_node(prefix)
    local meta = { __metatable = false, subnodes = {} }
    meta.__index = function (_, k)
        if meta.subnodes[k] then return meta.subnodes[k] end
        local full_path = (prefix and (prefix..".") or "") .. k
        local type = get_settings_path_type(full_path)
        if type == "value" then return settings_list[full_path].value end
        if type == "group" then
            meta.subnodes[k] = new_settings_node(full_path)
            return meta.subnodes[k]
        end
    end
    meta.__newindex = function (_, k, v)
        local full_path = (prefix and (prefix..".") or "") .. k
        local type = get_settings_path_type(full_path)
        if type == "group" then error("cannot assign a value to a settings group") end
        if type == "value" then settings_list[full_path].value = v end
    end
    return setmetatable({}, meta)
end

local root = new_settings_node()

return setmetatable(_M, { __index = root })

-- vim: et:sw=4:ts=8:sts=4:tw=80
