---------------------------------------------------------
-- Command completion                                  --
-- (C) 2010 Fabian Streitel <karottenreibe@gmail.com>  --
-- (C) 2010 Mason Larobina  <mason.larobina@gmail.com> --
---------------------------------------------------------

local key = lousy.bind.key
add_binds("command", {
    -- Start completion
    key({}, "Tab", function (w)
        local i = w.ibar.input
        -- Only complete commands, not args
        if string.match(i.text, "%s") then return end
        w:set_mode("cmdcomp")
    end),
})

-- Exit completion
local function exitcomp(w)
    w:enter_cmd(":" .. w.comp_state.orig)
end

-- Command completion binds
add_binds("cmdcomp", {
    key({},          "Tab",     function (w) w.menu:move_down() end),
    key({"Shift"},   "Tab",     function (w) w.menu:move_up()   end),
    key({},          "Escape",  exitcomp),
    key({"Control"}, "[",       exitcomp),
})

-- Create interactive menu of available command completions
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
        for _, b in ipairs(get_mode("command").binds) do
            if b.cmds then
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

-- vim: et:sw=4:ts=8:sts=4:tw=80
