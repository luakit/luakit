--- Clear website data.
--
-- This module provides an interface to clear website data, such as cache,
-- cookies, local storage and databases.
--
-- @module clear_data
-- @copyright 2019 Ulrik de Muelenaere <ulrikdem@gmail.com>

local binds = require("binds")
local lousy = require("lousy")
local modes = require("modes")

local _M = {}

local function format_bytes(bytes)
    if bytes < 1024 then
        return string.format("%d B", bytes)
    elseif bytes < 1024 * 1024 then
        return string.format("%.1f KiB", bytes / 1024)
    else
        return string.format("%.1f MiB", bytes / (1024 * 1204))
    end
end

local function list_data_types(data)
    local s = ""
    for _, data_type in ipairs(lousy.util.table.keys(data)) do
        s = s .. ", " .. data_type
        if data[data_type] ~= 0 then
            s = s .. " (" .. format_bytes(data[data_type]) .. ")"
        end
    end
    return s:sub(3)
end

modes.new_mode("clear-data", {
    enter = function (w)
        coroutine.wrap(function ()
            local rows = {
                {"Domain", "Data", title = true},
                {"all", "all", clear_all = true},
            }
            local website_data = luakit.website_data.fetch({"all"})
            for _, domain in ipairs(lousy.util.table.keys(website_data)) do
                table.insert(rows, {domain, list_data_types(website_data[domain])})
            end
            w.menu:build(rows)
            w:notify("Use j/k to move, Return to clear all data, or c/d/i/l/m/o/p/s/w for a specific type.", false)
        end)()
    end,

    leave = function (w)
        w.menu:hide()
    end,
})

local function add_clear_bind(bind, data_type)
    modes.add_binds("clear-data", {
        { bind, "Clear `"..data_type.."` for the focused domain.",
            function (w)
                local focused_row = w.menu:get()
                if not focused_row then
                    return
                end

                coroutine.wrap(function()
                    if focused_row.clear_all then
                        luakit.website_data.clear({data_type})
                    else
                        luakit.website_data.remove({data_type}, focused_row[1])
                    end

                    local website_data = luakit.website_data.fetch({"all"})
                    local i = 3 -- Skip title and "all" row
                    while w.menu:get(i) do
                        local row = w.menu:get(i)
                        local domain = row[1]
                        if website_data[domain] then
                            row[2] = list_data_types(website_data[domain])
                            i = i + 1
                        else
                            w.menu:del(i)
                        end
                    end
                    w.menu:update()
                end)()
            end },
    })
end

add_clear_bind("<Return>", "all")

for _, args in ipairs({
    {"m", "memory_cache"},
    {"d", "disk_cache"},
    {"o", "offline_application_cache"},
    {"s", "session_storage"},
    {"l", "local_storage"},
    {"w", "websql_databases"},
    {"i", "indexeddb_databases"},
    {"p", "plugin_data"},
    {"c", "cookies"},
}) do
    add_clear_bind(unpack(args))
end

modes.add_binds("clear-data", binds.menu_binds)

modes.add_cmds({
    { ":clear-data", "Open menu to clear website data.",
        function (w)
            w:set_mode("clear-data")
        end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
