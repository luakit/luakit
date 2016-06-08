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
            for ti, tab in ipairs(w.tabs.children) do
                table.insert(state, {wi = wi, ti = ti, current = (current ==
                ti), uri = tab.uri, session_state = tab.session_state })
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
        local ret = {}

        -- Read file
        local fh = io.open(session.file, "rb")
        local state = pickle.unpickle(fh:read("*all"))
        io.close(fh)
        -- Delete file
        if delete ~= false then rm(session.file) end

        -- Parse session file
        for _, line in ipairs(state) do
            if not ret[line.wi] then ret[line.wi] = {} end
            table.insert(ret[line.wi], { uri = line.uri, current = line.current, session_state = line.session_state })
        end

        return (#ret > 0 and ret) or nil
    end,

    -- Spawn windows from saved session and return the last window
    restore = function (delete)
        wins = session.load(delete)
        if not wins or #wins == 0 then return end

        -- Spawn windows
        local w
        for _, win in ipairs(wins) do
            w = nil
            for _, item in ipairs(win) do
                if not w then
                    w = window.new({{ session_state = item.session_state }})
                else
                    w:new_tab({ session_state = item.session_state }, item.current)
                end
            end
        end

        return w
    end,
}

-- Save current window session helper
window.methods.save_session = function (w)
    session.save({w,})
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
