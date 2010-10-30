-------------------------------
-- luakit mode configuration --
-------------------------------

-- Table of modes and their callback hooks
modes = {}

-- Currently active mode hooks and state data
local current

-- Update a modes hook table with new hooks
function new_mode(mode, hooks)
    modes[mode] = lousy.util.table.join(modes[mode] or {}, hooks)
end

-- Input bar history binds, these are only present in modes with a history
-- table so we can make some assumptions. This auto-magic is present when
-- a mode contains a `history` table item (with history settings therein).
local key = lousy.bind.key
hist_binds = {
    key({}, "Up", function (w)
        local h = current.history
        local lc = h.cursor
        if not h.cursor and h.len > 0 then
            h.cursor = h.len
        elseif (h.cursor or 0) > 1 then
            h.cursor = h.cursor - 1
        end
        if h.cursor and h.cursor ~= lc then
            if not h.orig then h.orig = w.ibar.input.text end
            w:set_input(h.items[h.cursor])
        end
    end),
    key({}, "Down", function (w)
        local h = current.history
        if not h.cursor then return end
        if (h.cursor + 1) >= h.len then
            w:set_input(h.orig)
            h.cursor = nil
            h.orig = nil
        else
            h.cursor = h.cursor + 1
            w:set_input(h.items[h.cursor])
        end
    end),
}

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

        -- Setup history state
        if current.history then
            local h = current.history
            if not h.items then h.items = {} end
            h.len = #(h.items)
            h.cursor = nil
            h.orig = nil
            -- Add Up & Down history bindings
            w.binds = lousy.util.table.join(hist_binds, w.binds)
            -- Trim history
            if h.maxlen and h.len > (h.maxlen * 1.5) then
                local items = {}
                for i = (h.len - h.maxlen), h.len do
                    table.insert(items, h.items[i])
                end
                h.items = items
                h.len = #items
            end
        end

        -- Call new modes `enter` hook.
        if current.enter then current.enter(w) end
    end)

    -- Calls the `changed` hook on input widget changed.
    w.ibar.input:add_signal("changed", function()
        if current and current.changed then
            current.changed(w, w.ibar.input.text)
        end
    end)

    -- Calls the `activate` hook on input widget activate.
    w.ibar.input:add_signal("activate", function()
        if current and current.activate then
            local text, hist = w.ibar.input.text, current.history
            if current.activate(w, text) == false or not hist then return end
            -- Check if last history item is identical
            if hist.items[hist.len] ~= text then table.insert(hist.items, text) end
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
        w:set_mode()
        local cmd = string.sub(text, 2)
        local success, match = pcall(w.match_cmd, w, cmd)
        if not success then
            w:error("In command call: " .. match)
        elseif not match then
            w:error(string.format("Not a browser command: %q", cmd))
        end
    end,
    history = {maxlen = 50},
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
            s = w.search_state
            s.last_search = string.sub(text, 2)
            if #text > 3 then
                w:search(string.sub(text, 2), (string.sub(text, 1, 1) == "/"))
                if s.ret == false and s.marker then w:get_current():set_scroll_vert(s.marker) end
            else
                w:clear_search(false)
            end
        else
            w:clear_search()
            w:set_mode()
        end
    end,
    activate = function (w, text)
        w.search_state.marker = nil
        -- Search if haven't already (won't have for short strings)
        if not w.search_state.searched then
            w:search(string.sub(text, 2), (string.sub(text, 1, 1) == "/"))
        end
        -- Ghost the last search term
        if w.search_state.ret then
            w:set_mode()
            w:set_prompt(text)
        else
            w:error("Pattern not found: " .. string.sub(text, 2))
        end
    end,
    history = {maxlen = 50},
})

new_mode("qmarks", {
    leave = function (w)
        w.menu:hide()
    end,
})

new_mode("proxy", {
    leave = function (w)
        w.menu:hide()
    end,
})

new_mode("undolist", {
    leave = function (w)
        w.menu:hide()
    end,
})

new_mode("cmdcomp", {
    enter = function (w)
        local i = w.ibar.input
        local text = i.text
        -- Clean state
        w.comp_state = {}
        local s = w.comp_state
        -- Get completion text
        s.orig = string.sub(text, 2)
        s.left = string.sub(text, 2, i.position)
        -- Make pattern
        local pat = "^" .. s.left
        -- Build completion table
        local cmpl = {{"Commands", title=true}}
        -- Get suitable commands
        for _, b in ipairs(binds.commands) do
            for i, c in ipairs(b.cmds) do
                if string.match(c, pat) and not string.match(c, "!$") then
                    if i == 1 then
                        c = ":" .. c
                    else
                        c = string.format(":%s (:%s)", c, b.cmds[1])
                    end
                    table.insert(cmpl, { c, cmd = b.cmds[1] })
                    break
                end
            end
        end
        -- Exit mode if no suitable commands found
        if #cmpl <= 1 then
            w:enter_cmd(text)
            return
        end
        -- Build menu
        w.menu:build(cmpl)
        w.menu:add_signal("changed", function(m, row)
            local pos
            if row then
                s.text = ":" .. row.cmd
                pos = #(row.cmd) + 1
            else
                s.text = ":" .. s.orig
                pos = #(s.left) + 1
            end
            -- Update input bar
            i.text = s.text
            i.position = pos
        end)
        -- Set initial position
        w.menu:move_down()
    end,

    leave = function (w)
        w.menu:hide()
        -- Remove all changed signal callbacks
        w.menu:remove_signals("changed")
    end,

    changed = function (w, text)
        -- Return if change was made by cycling through completion options.
        if text ~= w.comp_state.text then
            w:enter_cmd(text, { pos = w.ibar.input.position })
        end
    end,

    activate = function (w, text)
        w:enter_cmd(text .. " ")
    end,
})
