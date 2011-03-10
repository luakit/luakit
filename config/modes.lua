-------------------------------
-- luakit mode configuration --
-------------------------------

-- Table of modes and their callback hooks
local modes = {}

-- Add new mode table (merges with old table).
function new_mode(name, mode)
    assert(string.match(name, "^[%w-_]+$"), "invalid mode name: " .. name)
    modes[name] = lousy.util.table.join(modes[name] or {}, mode, { name = name })
end

-- Get mode table.
function get_mode(name)
    assert(string.match(name, "^[%w-_]+$"), "invalid mode name: " .. name)
    return modes[name]
end

-- Attach window & input bar signals for mode hooks
window.init_funcs.modes_setup = function (w)
    -- Calls the `enter` and `leave` mode hooks.
    w:add_signal("mode-changed", function (_, name)
        local leave = (w.mode or {}).leave

        -- Get new modes functions/hooks/data
        local mode = modes[name]
        w.mode = mode

        -- Call last modes leave hook.
        if leave then leave(w) end

        -- Check new mode
        if not mode then
            error("changed to un-handled mode: " .. name)
        end

        -- Update window binds
        w:update_binds(name)

        -- Call new modes enter hook.
        if mode.enter then mode.enter(w) end

        w:emit_signal("mode-entered", mode)
    end)

    -- Calls the changed hook on input widget changed.
    w.ibar.input:add_signal("changed", function ()
        local mode = w.mode
        if mode and mode.changed then
            mode.changed(w, w.ibar.input.text)
        end
    end)

    -- Calls the `activate` hook on input widget activate.
    w.ibar.input:add_signal("activate", function ()
        local mode = w.mode
        if mode and mode.activate then
            local text, hist = w.ibar.input.text, mode.history
            if mode.activate(w, text) == false then return end
            -- Check if last history item is identical
            if hist and hist.items and hist.items[hist.len or -1] ~= text then
                table.insert(hist.items, text)
            end
        end
    end)

end

-- Add mode related window methods
local mset, mget = lousy.mode.set, lousy.mode.get
for name, func in pairs({
    set_mode = function (w, name)        mset(w, name)   end,
    get_mode = function (w)       return mget(w)         end,
    is_mode  = function (w, name) return name == mget(w) end,
}) do window.methods[name] = func end

-- Setup normal mode
new_mode("normal", {
    enter = function (w)
        w:set_prompt()
        w:set_input()
    end,
})

-- Setup insert mode
new_mode("insert", {
    enter = function (w)
        w:set_prompt("-- INSERT --")
        w:set_input()
    end,
})

new_mode("passthrough", {
    enter = function (w)
        w:set_prompt("-- PASS THROUGH --")
        w:set_input()
    end,
})

-- Setup command mode
new_mode("command", {
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
        -- Ignore blank commands
        if string.match(cmd, "^%s*$") then return end
        local success, match = pcall(w.match_cmd, w, cmd)
        if not success then
            w:error("In command call: " .. match)
        elseif not match then
            w:error(string.format("Not a browser command: %q", cmd))
        end
    end,
    history = {maxlen = 50},
})

new_mode("lua", {
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
