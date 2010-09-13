--------------------------------------------------------
-- Session saving / loading functions                 --
-- (C) 2010 Mason Larobina <mason.larobina@gmail.com> --
--------------------------------------------------------

-- Session functions
session = {
    file = luakit.cache_dir .. "/session",

    save = function ()
        local lines = {}
        -- Get list of window structs
        local wins = {}
        for _, w in pairs(window.bywidget) do table.insert(wins, w) end
        -- Save uris from all tabs in all windows
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
            luakit.spawn(string.format("rm %q", session.file))
        end
    end,

    load = function ()
        if not os.exists(session.file) then return end
        local ret = {}
        local split = lousy.util.string.split
        local fh = io.lines(session.file, "r")
        for line in fh do
            local wi, ti, current, uri = unpack(split(line, "\t"))
            wi = tonumber(wi)
            current = (current == "true")
            if not ret[wi] then ret[wi] = {} end
            table.insert(ret[wi], { uri = uri, current = current })
        end

        -- Delete session
        luakit.spawn(string.format("rm %q", session.file))

        if #ret > 0 and #(ret[1]) > 0 then
            return ret
        else
            return nil
        end
    end,
}
