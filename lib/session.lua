--- Session saving / loading functions.
--
-- This module allows you to save your current session when quitting
-- luakit, and then restore it again the next time you open luakit.
--
-- This module also provides a Lua API to allow other modules to save data to
-- the session file and restore it when reopening Luakit.
--
-- @module session
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local window = require("window")
local webview = require("webview")
local lousy = require("lousy")
local pickle = lousy.pickle
local settings = require("settings")

local _M = {}

lousy.signal.setup(_M, true)

--- Path to session file.
-- @type string
-- @readwrite
_M.session_file = luakit.data_dir .. "/session"

--- Path to crash recovery session file.
-- @type string
-- @readwrite
_M.recovery_file = luakit.data_dir .. "/recovery_session"

--- Save the current session state to a file.
--
-- If no file is specified, the path specified by @ref{session_file} is used.
--
-- @tparam[opt] string file The file path in which to save the session state.
_M.save = function (file)
    if not file then file = _M.session_file end
    local state = {}
    local wins = lousy.util.table.values(window.bywidget)
    -- Save tabs from all windows
    for _, w in ipairs(wins) do
        local current = w.tabs:current()
        state[w] = { open = {} }
        for ti, tab in ipairs(w.tabs.children) do
            if tab.private then
                table.insert(state[w].open, { private = true })
            else
                table.insert(state[w].open, {
                    ti = ti,
                    current = (current == ti),
                    uri = tab.uri,
                    session_state = tab.session_state
                })
            end
        end
    end
    _M.emit_signal("save", state)

    for _, ws in pairs(state) do
        for i=#ws.open,1,-1 do
            if ws.open[i].private then table.remove(ws.open, i) end
        end
    end

    -- Convert state keys from w to an index
    local istate = {}
    for i, w in ipairs(wins) do
        assert(type(state[w]) == "table")
        istate[i] = state[w]
    end
    state = istate

    if #state > 0 then
        local tempfile = file .. ".new"
        local fh = io.open(tempfile, "wb")
        fh:write(pickle.pickle(state))
        io.close(fh)
        os.rename(tempfile, file)
    else
        os.remove(file)
    end
end

--- Load session state from a file, and optionally delete it.
--
-- The session state is *not* restored. This function only loads the state into
-- a table and returns it.
--
-- If no file is specified, the path specified by @ref{session_file} is used.
--
-- If `delete` is not `false` and the session file is not the recovery file,
-- then the session file is backed up into the recovery file.
--
-- @tparam[opt] boolean delete Whether to delete the file after the session is
-- loaded.
-- @tparam[opt] string file The file path from which to load the session state.
_M.load = function (delete, file)
    if not file then file = _M.session_file end
    if not os.exists(file) then return {} end

    -- Read file
    local fh = io.open(file, "rb")
    local state = pickle.unpickle(fh:read("*all"))
    io.close(fh)
    -- Backup file on idle (i.e. only if config loads successfully)
    if delete ~= false and file ~= _M.recovery_file then
        luakit.idle_add(function() os.rename(file, _M.recovery_file) end)
    end

    return state
end

-- Spawn windows from saved session and return the last window
local restore_file = function (file, delete)
    local ok, wins = pcall(_M.load, delete, file)
    if not ok or #wins == 0 then return end

    local state = {}
    -- Spawn windows
    local w
    for _, win in ipairs(wins) do
        w = nil
        for _, item in ipairs(win.open) do
            local v
            if not w then
                w = window.new({settings.get_setting("window.new_tab_page")})
                v = w.view
            else
                v = w:new_tab(settings.get_setting("window.new_tab_page"), { switch = item.current })
            end
            -- Block the tab load, then set its location
            webview.modify_load_block(v, "session-restore", true)
            webview.set_location(v, { session_state = item.session_state, uri = item.uri })
            local function unblock(vv)
                webview.modify_load_block(vv, "session-restore", false)
                vv:remove_signal("switched-page", unblock)
            end
            v:add_signal("switched-page", unblock)
        end
        -- Convert state keys from index to w table
        if w then state[w] = win end
    end
    _M.emit_signal("restore", state)

    return w
end

--- Restore the session state, optionally deleting the session file.
--
-- This will first attempt to restore the session saved at @ref{session_file}. If
-- that does not succeed, the session saved at `recovery_file` will be loaded.
--
-- If `delete` is not `false`, then the loaded session file is deleted.
--
-- @tparam[opt] boolean delete Whether to delete the file after the session is
-- restored.
-- @treturn[1] table The window table for the last window created.
-- @treturn[2] nil If no session could be loaded, `nil` is returned.
_M.restore = function(delete)
    return restore_file(_M.session_file, delete)
        or restore_file(_M.recovery_file, delete)
end

local session_dirty = true
local recovery_save_timer

settings.register_settings({
    ["session.recovery_save_interval"] = {
        type = "number",
        default = 30,
        validator = function (v)
            return tonumber(v) >= 0
        end,
        desc = [[
            The minimum time to wait in seconds after a browsing action before
            saving the recovery session. Must be non-negative.
        ]],
    },
})

settings.add_signal("setting-changed", function (e)
    if e.key == "session.recovery_save_interval" then
        recovery_save_timer.interval = e.value*1000
    end
end)

recovery_save_timer = timer{
    interval = settings.get_setting("session.recovery_save_interval")*1000
}

-- Save current window session helper
window.methods.save_session = function ()
    if not session_dirty then return end
    session_dirty = false
    _M.save(_M.session_file)
end

local function start_timeout()
    -- Restart the timer
    if recovery_save_timer.started then
        recovery_save_timer:stop()
    end
    recovery_save_timer:start()
    session_dirty = true
end

recovery_save_timer:add_signal("timeout", function ()
    recovery_save_timer:stop()
    _M.save(_M.recovery_file)
end)

window.add_signal("init", function (w)
    w.win:add_signal("destroy", function ()
        -- Hack: should add a luakit shutdown hook...
        local num_windows = #lousy.util.table.values(window.bywidget)
        -- Remove the recovery session on a successful exit
        if num_windows == 0 and os.exists(_M.recovery_file) then
            os.remove(_M.recovery_file)
        end
    end)

    w:add_signal("close", function ()
        if #lousy.util.table.values(window.bywidget) > 1 then
            start_timeout()
            return
        end
        if not settings.get_setting("session.always_save") then return end
        if w.tabs:count() == 0 then return end -- window.close_with_last_tab...
        w:save_session()
    end)

    w.tabs:add_signal("page-reordered", function ()
        start_timeout()
    end)
end)

webview.add_signal("init", function (view)
    -- Save session state after page navigation
    view:add_signal("load-status", function (_, status)
        if status == "committed" then
            start_timeout()
        end
    end)
    -- Save session state after switching page (session includes current tab)
    view:add_signal("switched-page", function ()
        start_timeout()
    end)
end)

settings.register_settings({
    ["session.always_save"] = {
        type = "boolean",
        default = false,
        desc = [[
            Whether the current browsing session should always be saved
            just before luakit is exited.
        ]],
    },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
