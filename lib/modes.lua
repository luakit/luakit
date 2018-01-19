--- Default mode configuration for luakit.
--
-- This module defines a core set of modes each luakit window can be in.
-- Different modes recognize different keybindings.
--
-- @module modes
-- @author Aidan Holm <aidanholm@gmail.com>
-- @author Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local _M = {}

local window = require("window")
local webview = require("webview")

-- Table of modes and their callback hooks
local modes = {}
local lousy = require "lousy"
local join = lousy.util.table.join
local order = 0

--- Add a new mode table (optionally merges with original mode)
-- @tparam string name The name of the mode.
-- @tparam[opt] string desc The description of the mode.
-- @tparam table mode A table that defines the mode.
-- @tparam[opt] boolean replace `true` if any existing mode with the same name should
-- be replaced, and `false` if the pre-existing mode should be extended.
-- @default `false`
_M.new_mode = function (name, desc, mode, replace)
    assert(string.match(name, "^[%w-_]+$"), "invalid mode name: " .. name)
    -- Detect optional description
    if type(desc) == "table" then
        desc, mode, replace = nil, desc, mode
    end
    local traceback = debug.traceback("Creation traceback:", 2)
    order = order + 1
    modes[name] = join({ order = order, traceback = traceback },
        (not replace and modes[name]) or {}, mode or {},
        { name = name, desc = desc })
end

--- Get a mode by name.
-- @tparam string name The name of the mode to retrieve.
-- @treturn table The mode table for the named mode.
_M.get_mode = function(name) return modes[name] end

--- Get all modes.
-- @treturn table A clone of the full table of modes.
_M.get_modes = function () return lousy.util.table.clone(modes) end

-- Attach window & input bar signals for mode hooks
window.add_signal("init", function (w)
    -- Calls the `enter` and `leave` mode hooks.
    w:add_signal("mode-changed", function (_, name, ...)
        local leave = (w.mode or {}).leave

        -- Get new modes functions/hooks/data
        local mode = assert(modes[name], "invalid mode: " .. name)

        -- Call last modes leave hook.
        if leave then leave(w) end

        -- Create w.mode object
        w.mode = mode

        -- Update window binds
        w:update_binds(name)

        -- Call new modes enter hook.
        if mode.enter then mode.enter(w, ...) end
        w.last_mode_entered = mode

        w:emit_signal("mode-entered", mode)
    end)

    local input = w.ibar.input

    -- Calls the changed hook on input widget changed.
    input:add_signal("changed", function ()
        local changed = w.mode.changed
        -- the w:set_input() in normal mode's enter function would create a
        -- changed signal which would run before the next mode's enter
        -- function, usually causing a change back to normal mode before the
        -- next mode's enter function actually ran.
        -- here, we only run the changed callback if the current mode matches
        -- the last mode entered.
        if changed and w.last_mode_entered == w.mode then
            changed(w, input.text)
        end
    end)

    input:add_signal("property::position", function ()
        local move_cursor = w.mode.move_cursor
        if move_cursor then move_cursor(w, input.position) end
    end)

    -- Calls the `activate` hook on input widget activate.
    input:add_signal("activate", function ()
        local mode = w.mode
        if mode and mode.activate then
            local text = input.text
            -- Activates the mode.
            if mode.activate(w, text) == false then return end
            -- Prevents recording command history if in a private tab, or
            -- recording the `:priv-tabopen` command itself.
            if w.view and w.view.private then return end
            local hist = mode.history
            -- Check if last history is identical
            if hist and hist.items and hist.items[hist.len or -1] ~= text then
                table.insert(hist.items, text)
                -- Dump history
                local t = {}
                for k, v in pairs(modes) do
                    if v.history then
                        t[k] = v.history.items
                    end
                end
                local f = io.open(luakit.data_dir .. "/command-history", "w")
                if f then
                    f:write(lousy.pickle.pickle(t))
                    f:close()
                end
            end
        end
    end)
end)

-- Add mode related window methods
window.methods.set_mode = lousy.mode.set
local mget = lousy.mode.get
window.methods.is_mode = function (w, name) return name == mget(w) end

webview.add_signal("init", function (view)
    view.can_focus = false
end)

-- Setup normal mode
_M.new_mode("normal", [[When luakit first starts you will find yourself in this
    mode.]], {
    enter = function (w)
        w:set_prompt()
        w:set_input()
        if w.view then w.view.can_focus = false end
        w.win:focus()
    end,
})

_M.new_mode("all", "Special meta-mode in which the bindings for this mode are present in all modes.")

-- Setup insert mode
_M.new_mode("insert", [[When clicking on form fields luakit will enter the insert
    mode which allows you to enter text in form fields without accidentally
    triggering normal mode bindings.]], {
    enter = function (w)
        w:set_prompt("-- INSERT --")
        w:set_input()
        w.view.can_focus = true
        w.view:focus()
    end,
    -- Send key events to webview
    passthrough = true,
})

_M.new_mode("passthrough", [[Luakit will pass every key event to the WebView
    until the user presses Escape.]], {
    enter = function (w)
        w:set_prompt("-- PASS THROUGH --")
        w:set_input()
        w.view.can_focus = true
        w.view:focus()
    end,
    -- Send key events to webview
    passthrough = true,
    -- Don't exit mode when clicking outside of form fields
    reset_on_focus = false,
    -- Don't exit mode on navigation
    reset_on_navigation = false,
})

-- Setup command mode
_M.new_mode("command", [[Enter commands.]], {
    enter = function (w)
        w:set_prompt()
        w:set_input(":")
    end,
    changed = function (w, text)
        -- Auto-exit command mode if user backspaces ":" in the input bar.
        if not string.match(text, "^:") then w:set_mode() end
    end,
    activate = function (w, text)
        w:set_mode()
        local cmd = string.sub(text, 2)
        if not string.find(cmd, "%S") then return end

        local success, match = xpcall(
            function () return w:match_cmd(cmd) end,
            function (err) w:error(debug.traceback(err, 3)) end)

        if success and not match then
            w:error(string.format("Not a browser command: %q", cmd))
        end
    end,
    history = {maxlen = 50},
})

_M.new_mode("lua", [[Execute arbitrary Lua commands within the luakit
    environment.]], {
    enter = function (w)
        w:set_prompt(">")
        w:set_input("")
    end,
    activate = function (w, text)
        w:set_input("")
        local ret = assert(loadstring("return function(w) return "..text.." end"))()(w)
        if ret then print(ret) end
    end,
    history = {maxlen = 50},
})

--- Callback type for a bind action.
-- @callback bind_action_cb
-- @tparam table w The window table for the window on which the binding was
-- activated.
-- @tparam table opts Combined table of bind-time and invocation-time options.
-- @tparam table bind_opts Table of invocation-time options.
-- @treturn boolean `false` if bind matching should be continued, as if this
-- action were not bound. Any other value stops bind matching, which is usually
-- what you want.

--- Add a set of binds to one or more modes. Any pre-existing binds with the
-- same trigger will be removed automatically.
--
-- # Example
--
-- The following code snippet will rebind `Control-c` to copy text selected with
-- the mouse, and the default binding for `Control-c` will be removed.
--
--     modes.add_binds("normal", {
--         { "<Control-c>", "Copy selected text.", function ()
--             luakit.selection.clipboard = luakit.selection.primary
--         end},
--     })
--
-- # Bind format
--
-- Every item in the `binds` array must be a table that defines a single binding
-- between a trigger and an action. Each entry must have the following form:
--
--     { trigger, description, action, options }
--
-- - `trigger` is a string describing the combination of keys/modifiers/buttons
--   that will trigger the associated action.
-- - `description` is an optional string. Any description will show up in the
--   introspector.
-- - `action` is a function that will be called when the binding is
--   activated, of type @ref{bind_action_cb}.
-- - `options` is a table of bind-time options passed to the `action` callback.
--
-- @tparam table|string mode The name of the mode, or an array of mode names.
-- @tparam table binds An array of binds to add to each of the named modes.
_M.add_binds = function (mode, binds)
    mode = type(mode) ~= "table" and {mode} or mode
    for _, name in ipairs(mode) do
        local mdata = assert(_M.get_mode(name), "mode '"..name.."' doesn't exist")
        mdata.binds = mdata.binds or {}
        for _, m in ipairs(binds) do
            local bind, desc, action, opts = unpack(m)
            if type(desc) ~= "string" then
                desc, action, opts = nil, desc, action
            end
            if type(desc) == "string" or type(action) == "function" then -- Make ad-hoc action
                action = type(action) == "table" and lousy.util.table.clone(action) or { func = action }
                action.desc = desc
            end
            lousy.bind.add_bind(mdata.binds, bind, action, opts)
        end
    end
end

--- Remove a set of binds from one or more modes.
--
-- # Example
--
--     -- Disable extra zooming commands
--     modes.remove_binds("normal", { "zi", "zo", "zz" })
--
--     -- Disable passthrough mode
--     modes.remove_binds({"normal", "insert"}, { "<Control-z>" })
--
-- @tparam table|string mode The name of the mode, or an array of mode names.
-- @tparam table binds An array of binds to remove from each of the named modes.
_M.remove_binds = function (mode, binds)
    mode = type(mode) ~= "table" and {mode} or mode
    for _, name in ipairs(mode) do
        local mdata = assert(_M.get_mode(name), "mode '"..name.."' doesn't exist")
        for _, bind in ipairs(binds) do
            lousy.bind.remove_bind(mdata.binds or {} , bind)
        end
    end
end

--- Bind an existing key or command to a new binding.
--
-- # Example
--
--     -- Add an additional zooming command binding
--     modes.remap_binds("normal", {
--         { "<Control-=>", "zi", true },
--     })
--
-- # Bind format
--
-- Every item in the `binds` array must be a table that defines a single rebind
-- from an existing trigger to a new one. Each entry must have the following form:
--
--     { new, old, keep }
--
-- - `new` is a string describing the combination of keys/modifiers/buttons
--   that will trigger the associated action.
-- - `old` is a string describing the previous trigger of the action.
-- - `keep` is an optional argument that determines whether the existing binding
--   should remain. Defaults to `false` if not present.
--
-- @tparam table|string mode The name of the mode, or an array of mode names.
-- @tparam table binds An array of binds to remap
_M.remap_binds = function(mode, binds)
    mode = type(mode) ~= "table" and {mode} or mode
    for _, name in ipairs(mode) do
        local mdata = assert(_M.get_mode(name), "mode '"..name.."' doesn't exist")
        for _, bind in ipairs(binds) do
            local new, old, keep = unpack(bind)
            lousy.bind.remap_bind(mdata.binds or {}, new, old, keep)
        end
    end
end

--- Add a set of commands to the built-in `command` mode.
-- @tparam table|string mode The name of the mode, or an array of mode names.
-- @tparam table binds An raray of binds to add to each of the named modes.
_M.add_cmds = function (binds)
    for _, m in ipairs(binds) do
        local b = m[1]
        if b and b:match("^[^<^]") then
            for _, c in ipairs(lousy.util.string.split(b, ",%s+")) do
                assert(c:match("^:[%[%]%w%-!]+$"), "Bad command binding '" .. b .. "'")
            end
        end
    end
    _M.add_binds("command", binds)
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
