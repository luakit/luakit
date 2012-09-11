-------------------------------
-- luakit mode configuration --
-------------------------------

-- Table of modes and their callback hooks
local modes = {}
local lousy = require "lousy"
local join = lousy.util.table.join
local order = 0

-- Add new mode table (optionally merges with original mode)
function new_mode(name, desc, mode, replace)
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

-- Get mode table
function get_mode(name) return modes[name] end

function get_modes() return lousy.util.table.clone(modes) end

-- Attach window & input bar signals for mode hooks
window.init_funcs.modes_setup = function (w)
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

        w:emit_signal("mode-entered", mode)
    end)

    local input = w.ibar.input

    -- Calls the changed hook on input widget changed.
    input:add_signal("changed", function ()
        local changed = w.mode.changed
        if changed then changed(w, input.text) end
    end)

    input:add_signal("property::position", function ()
        local move_cursor = w.mode.move_cursor
        if move_cursor then move_cursor(w, input.position) end
    end)

    -- Calls the `activate` hook on input widget activate.
    input:add_signal("activate", function ()
        local mode = w.mode
        if mode and mode.activate then
            local text, hist = input.text, mode.history
            if mode.activate(w, text) == false then return end
            -- Check if last history item is identical
            if hist and hist.items and hist.items[hist.len or -1] ~= text then
                table.insert(hist.items, text)
            end
        end
    end)
end

-- Add mode related window methods
window.methods.set_mode = lousy.mode.set
local mget = lousy.mode.get
window.methods.is_mode = function (w, name) return name == mget(w) end

-- Setup normal mode
new_mode("normal", [[When luakit first starts you will find yourself in this
    mode.]], {
    enter = function (w)
        w:set_prompt()
        w:set_input()
    end,
})

new_mode("all", [[Special meta-mode in which the bindings for this mode are
    present in all modes.]])

-- Setup insert mode
new_mode("insert", [[When clicking on form fields luakit will enter the insert
    mode which allows you to enter text in form fields without accidentally
    triggering normal mode bindings.]], {
    enter = function (w)
        w:set_prompt("-- INSERT --")
        w:set_input()
        w.view:focus()
    end,
    -- Send key events to webview
    passthrough = true,
})

new_mode("passthrough", [[Luakit will pass every key event to the WebView
    until the user presses Escape.]], {
    enter = function (w)
        w:set_prompt("-- PASS THROUGH --")
        w:set_input()
    end,
    -- Send key events to webview
    passthrough = true,
    -- Don't exit mode when clicking outside of form fields
    reset_on_focus = false,
    -- Don't exit mode on navigation
    reset_on_navigation = false,
})

-- Setup command mode
new_mode("command", [[Enter commands.]], {
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

new_mode("lua", [[Execute arbitrary Lua commands within the luakit
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
