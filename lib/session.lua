--------------------------------------------------------
-- Session saving / loading functions                 --
-- (C) 2010 Mason Larobina <mason.larobina@gmail.com> --
--------------------------------------------------------

local function rm(file)
    luakit.spawn(string.format("rm %q", file))
end

-- Session functions
session = {
    file = luakit.cache_dir .. "/session",

    -- Save all given windows uris to file.
    save = function (wins)
        local lines = {}
        -- Save tabs from all the given windows
        for wi, w in pairs(wins) do
            local current = w.tabs:current()
            for ti = 1, w.tabs:count() do
                local uri = w.tabs:atindex(ti).uri or "about:blank"
                table.insert(lines, string.format("%d\t%d\t%s\t%s", wi, ti, tostring(current == ti), uri))
            end
        end

        if #lines > 0 then
            -- Save to $XDG_CACHE_HOME/luakit/session
            local fh = io.open(session.file, "w")
            fh:write(table.concat(lines, "\n"))
            io.close(fh)
        else
            rm(session.file)
        end
    end,

    -- Load window and tab state from file
    load = function ()
        if not os.exists(session.file) then return end
        local ret = {}

        -- Read file
        local lines = {}
        local fh = io.open(session.file, "r")
        for line in fh:lines() do table.insert(lines, line) end
        io.close(fh)
        -- Delete file
        rm(session.file)

        -- Parse session file
        local split = lousy.util.string.split
        for _, line in ipairs(lines) do
            local wi, ti, current, uri = unpack(split(line, "\t"))
            wi = tonumber(wi)
            current = (current == "true")
            if not ret[wi] then ret[wi] = {} end
            table.insert(ret[wi], {uri = uri, current = current})
        end

        return (#ret > 0 and ret) or nil
    end,

    -- Spawn windows from saved session and return the last window
    restore = function ()
        wins = session.load()
        if not wins or #wins == 0 then return end

        -- Spawn windows
        local w
        for _, win in ipairs(wins) do
            w = nil
            for _, item in ipairs(win) do
                if not w then
                    w = window.new({item.uri})
                else
                    w:new_tab(item.uri, item.current)
                end
            end
        end

        return w
    end,
}

-- Save current window session helper
window.methods.save_session = function (w)
    session.save{w}
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
