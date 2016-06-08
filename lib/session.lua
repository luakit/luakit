------------------------------------------------------
-- Session saving / loading functions               --
-- © 2010 Mason Larobina <mason.larobina@gmail.com> --
------------------------------------------------------

local pickle = lousy.pickle

local function rm(file)
    luakit.spawn(string.format("rm %q", file))
end

-- Session functions
session = {
    -- The file which we'll use for session info, $XDG_DATA_HOME/luakit/session
    file = luakit.data_dir .. "/session",

    -- Save all given windows uris to file.
    save = function (wins)
        local state = {}
        -- Save tabs from all the given windows
        for wi, w in pairs(wins) do
            local current = w.tabs:current()
            state[wi] = { open = {}, closed = w.closed_tabs }
            for ti, tab in ipairs(w.tabs.children) do
                table.insert(state[wi].open, {
                    ti = ti,
                    current = (current == ti),
                    uri = tab.uri,
                    session_state = tab.session_state
                })
            end
        end

        if #state > 0 then
            local fh = io.open(session.file, "wb")
            fh:write(pickle.pickle(state))
            io.close(fh)
        else
            rm(session.file)
        end
    end,

    -- Load window and tab state from file
    load = function (delete)
        if not os.exists(session.file) then return end

        -- Read file
        local fh = io.open(session.file, "rb")
        local state = pickle.unpickle(fh:read("*all"))
        io.close(fh)
        -- Delete file
        if delete ~= false then rm(session.file) end

        return (#state > 0 and state) or nil
    end,

    -- Spawn windows from saved session and return the last window
    restore = function (delete)
        wins = session.load(delete)
        if not wins or #wins == 0 then return end

        -- Spawn windows
        local w
        for _, win in pairs(wins) do
            w = nil
            for _, item in ipairs(win.open) do
                if not w then
                    w = window.new({{ session_state = item.session_state }})
                else
                    w:new_tab({ session_state = item.session_state }, item.current)
                end
            end
            w.closed_tabs = win.closed
        end

        return w
    end,
}

-- Save current window session helper
window.methods.save_session = function (w)
    session.save({w,})
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
