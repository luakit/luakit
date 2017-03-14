--- Session saving / loading functions.
--
-- @module session
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local window = require("window")
local webview = require("webview")
local lousy = require("lousy")
local pickle = lousy.pickle

local _M = {}

lousy.signal.setup(_M, true)

local function rm(file)
    luakit.spawn(string.format("rm %q", file))
end

-- The file which we'll use for session info, $XDG_DATA_HOME/luakit/session
_M.session_file = luakit.data_dir .. "/session"

-- Crash recovery session file
_M.recovery_file = luakit.data_dir .. "/recovery_session"

-- Save all given windows uris to file.
_M.save = function (file)
    if not file then file = _M.session_file end
    local state = {}
    local wins = lousy.util.table.values(window.bywidget)
    -- Save tabs from all windows
    for _, w in ipairs(wins) do
        local current = w.tabs:current()
        state[w] = { open = {} }
        for ti, tab in ipairs(w.tabs.children) do
            table.insert(state[w].open, {
                ti = ti,
                current = (current == ti),
                uri = tab.uri,
                session_state = tab.session_state
            })
        end
    end
    _M.emit_signal("save", state)

    -- Convert state keys from w to an index
    local istate = {}
    for i, w in ipairs(wins) do
        assert(type(state[w]) == "table")
        istate[i] = state[w]
    end
    state = istate

    if #state > 0 then
        local fh = io.open(file, "wb")
        fh:write(pickle.pickle(state))
        io.close(fh)
    else
        rm(file)
    end
end

-- Load window and tab state from file
_M.load = function (delete, file)
    if not file then file = _M.session_file end
    if not os.exists(file) then return {} end

    -- Read file
    local fh = io.open(file, "rb")
    local state = pickle.unpickle(fh:read("*all"))
    io.close(fh)
    -- Delete file
    if delete ~= false then rm(file) end

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
            if not w then
                w = window.new({{ session_state = item.session_state, uri = item.uri }})
            else
                w:new_tab({ session_state = item.session_state, uri = item.uri  }, item.current)
            end
        end
        -- Convert state keys from index to w table
        state[w] = win
    end
    _M.emit_signal("restore", state)

    return w
end

_M.restore = function(delete)
    return restore_file(_M.session_file, delete)
        or restore_file(_M.recovery_file, delete)
end

local recovery_save_timer = timer{ interval = 10*1000 }

-- Save current window session helper
window.methods.save_session = function ()
    _M.save(_M.session_file)
end

local function start_timeout()
    -- Restart the timer
    if recovery_save_timer.started then
        recovery_save_timer:stop()
    end
    recovery_save_timer:start()
end

recovery_save_timer:add_signal("timeout", function ()
    recovery_save_timer:stop()
    _M.save(_M.recovery_file)
end)

window.init_funcs.session_init = function(w)
    w.win:add_signal("destroy", function ()
        -- Hack: should add a luakit shutdown hook...
        local num_windows = 0
        for _, _ in pairs(window.bywidget) do num_windows = num_windows + 1 end
        -- Remove the recovery session on a successful exit
        if num_windows == 0 and os.exists(_M.recovery_file) then
            rm(_M.recovery_file)
        end
    end)

    w.tabs:add_signal("page-reordered", function ()
        start_timeout()
    end)
end

webview.init_funcs.session_init = function(view)
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
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
