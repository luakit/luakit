-------------------------------
-- luakit mode configuration --
-------------------------------

-- Table of modes and their callback hooks
modes = {}

-- Currently active mode hooks
local current

-- Update a modes hook table with new hooks
function new_mode(mode, hooks)
    modes[mode] = lousy.util.table.join(modes[mode] or {}, hooks)
end

-- Attach window & input bar signals for mode hooks
window.init_funcs.modes_setup = function (w)
    -- Calls the `enter` and `leave` mode hooks.
    w.win:add_signal("mode-changed", function (_, mode)
        local leave = (current or {}).leave

        -- Get new modes functions
        current = modes[mode]

        -- Call the last modes `leave` hook.
        if leave then leave(w) end

        -- Check new mode
        if not current then
            error("changed to un-handled mode: " .. mode)
        end

        -- Update window binds
        w:update_binds(mode)

        -- Call new modes `enter` hook.
        if current.enter then current.enter(w) end
    end)

    -- Calls the `changed` hook on input widget changed.
    w.ibar.input:add_signal("changed", function()
        local text = w.ibar.input.text
        if current and current.changed then
            current.changed(w, text)
        end
    end)

    -- Calls the `activate` hook on input widget activate.
    w.ibar.input:add_signal("activate", function()
        local text = w.ibar.input.text
        if current and current.activate then
            current.activate(w, text)
        end
    end)
end

-- Add mode related window methods
for name, func in pairs({
    set_mode = function (w, name) lousy.mode.set(w.win, name)  end,
    get_mode = function (w)       return lousy.mode.get(w.win) end,
    is_mode  = function (w, name) return name == w:get_mode()  end,
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
        w:cmd_hist_add(text)
        w:set_mode()
        local cmd = string.sub(text, 2)
        local success, match = pcall(w.match_cmd, w, cmd)
        if not success then
            w:error("In command call: " .. match)
        elseif not match then
            w:error(string.format("Not a browser command: %q", cmd))
        end
    end,
})

-- Setup search mode
new_mode("search", {
    enter = function (w)
        -- Clear old search state
        w.search_state = {}
        w:set_prompt()
        w:set_input("/")
    end,
    leave = function (w)
        -- Check if search was aborted and return to original position
        local s = w.search_state
        if s.marker then
            w:get_current():set_scroll_vert(s.marker)
            s.marker = nil
        end
    end,
    changed = function (w, text)
        -- Check that the first character is '/' or '?' and update search
        if string.match(text, "^[\?\/]") then
            w:search(string.sub(text, 2), (string.sub(text, 1, 1) == "/"))
        else
            w:clear_search()
            w:set_mode()
        end
    end,
    activate = function (w, text)
        w.search_state.marker = nil
        w:srch_hist_add(text)
        w:set_mode()
        -- Ghost the search term in the prompt
        w:set_prompt(text)
    end,
})
