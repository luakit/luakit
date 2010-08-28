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
        -- Call the last modes `leave` hook.
        if current and current.leave then
            current.leave(w)
        end

        -- Update window binds
        w:update_binds(mode)

        -- Get new modes functions
        current = modes[mode]
        if not current then
            error("changed to un-handled mode: " .. mode)
        end

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
        local i, p = w.ibar.input, w.ibar.prompt
        i:hide()
        p:hide()
    end,
})

-- Setup insert mode
new_mode("insert", {
    enter = function (w)
        local i, p = w.ibar.input, w.ibar.prompt
        i:hide()
        i.text = ""
        p.text = "-- INSERT --"
        p:show()
    end,
})

-- Setup command mode
new_mode("command", {
    enter = function (w)
        local i, p = w.ibar.input, w.ibar.prompt
        p:hide()
        i.text = ":"
        i:show()
        i:focus()
        i:set_position(-1)
    end,
    changed = function (w, text)
        -- Auto-exit command mode if user backspaces ":" in the input bar.
        if not string.match(text, "^:") then w:set_mode() end
    end,
    activate = function (w, text)
        w:cmd_hist_add(text)
        w:match_cmd(string.sub(text, 2))
        w:set_mode()
    end,
})

-- Setup search mode
new_mode("search", {
    enter = function (w)
        -- Clear old search state
        w.search_state = {}
        local i, p = w.ibar.input, w.ibar.prompt
        p:hide()
        p.text = ""
        i.text = "/"
        i:show()
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
        local p = w.ibar.prompt
        p.text = lousy.util.escape(text)
        p:show()
    end,
})

-- Setup follow mode
new_mode("follow", {
    enter = function (w)
        local i, p = w.ibar.input, w.ibar.prompt
        w:eval_js_from_file(lousy.util.find_data("scripts/follow.js"))
        w:eval_js("clear(); show_hints();")
        p.text = "Follow:"
        p:show()
        i.text = ""
        i:show()
        i:focus()
        i:set_position(-1)
    end,
    leave = function (w)
        if w.eval_js then w:eval_js("clear();") end
    end,
    changed = function (w, text)
        local ret = w:eval_js(string.format("update(%q);", text))
        w:emit_form_root_active_signal(ret)
    end,
})
