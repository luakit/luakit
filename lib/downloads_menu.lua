local downloads = require("downloads")
local lousy = require("lousy")
local ipairs = ipairs
local table = table
local download = download
local string = string

local new_mode, add_binds, add_cmds = new_mode, add_binds, add_cmds
local menu_binds = menu_binds

module("downloads.menu")

-- Refreshes all download menus.
local function refresh(w)
    if w:get_mode() == "dllist" then
        w.menu:update()
    end
end

table.insert(downloads.refresh_functions, refresh)

-- Add menu commands.
local cmd = lousy.bind.cmd
add_cmds({
    -- View all downloads in an interactive menu
    cmd("downloads", function (w) w:set_mode("dllist") end),
})

-- Add mode to display all downloads in an interactive menu.
new_mode("dllist", {
    enter = function (w)
        local rows = {{ "Download", "Status", title = true }}
        for _, d in ipairs(downloads.downloads) do
            local function name()
                local i = lousy.util.table.hasitem(downloads.downloads, d) or 0
                return string.format("%3s %s", i, download.basename(d))
            end
            local function status()
                if download.is_running(d) then
                    return string.format("%.2f/%.2f Mb (%i%%) at %.1f Kb/s", d.current_size/1048576,
                        d.total_size/1048576, (d.progress * 100), download.speed(d))
                else
                    return d.status
                end
            end
            table.insert(rows, { name, status, dl = d })
        end
        if #rows > 1 then
            w.menu:build(rows)
            w:notify("Use j/k to move, d delete, c cancel, r restart, o open.", false)
        else
            w:notify("No downloads to list")
        end
    end,

    leave = function (w)
        w.menu:hide()
    end,
})

-- Add additional binds to downloads menu mode.
local key = lousy.bind.key
add_binds("dllist", lousy.util.table.join({
    -- Delete download
    key({}, "d",
        function (w)
            local row = w.menu:get()
            if row and row.dl then
                local i = lousy.util.table.hasitem(downloads.downloads, row.dl)
                downloads.delete(i)
                w.menu:del()
            end
        end),

    -- Cancel download
    key({}, "c",
        function (w)
            local row = w.menu:get()
            if row and row.dl then
                local i = lousy.util.table.hasitem(downloads.downloads, row.dl)
                downloads.cancel(i)
            end
        end),

    -- Open download
    key({}, "o",
        function (w)
            local row = w.menu:get()
            if row and row.dl then
                local i = lousy.util.table.hasitem(downloads.downloads, row.dl)
                downloads.open(i)
            end
        end),

    -- Restart download
    key({}, "r",
        function (w)
            local row = w.menu:get()
            if row and row.dl then
                local i = lousy.util.table.hasitem(downloads.downloads, row.dl)
                downloads.restart(i)
            end
        end),

    -- Exit menu
    key({}, "q", function (w) w:set_mode() end),

}, menu_binds))
