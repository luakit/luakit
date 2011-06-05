------------------------------------------------------------
-- Command completion                                     --
-- © 2010-2011 Mason Larobina  <mason.larobina@gmail.com> --
-- © 2010 Fabian Streitel <karottenreibe@gmail.com>       --
------------------------------------------------------------

-- Get Lua environment
local ipairs = ipairs
local setmetatable = setmetatable
local string = string
local table = table
local unpack = unpack

-- Get luakit environment
local lousy = require "lousy"
local sql_escape, escape = lousy.util.sql_escape, lousy.util.escape
local history = require "history"
local new_mode, get_mode = new_mode, get_mode
local add_binds = add_binds
local capi = { luakit = luakit }

module "completion"

-- Store completion state (indexed by window)
local data = setmetatable({}, { __mode = "k" })

-- Add completion start trigger
local key = lousy.bind.key
add_binds("command", {
    key({}, "Tab", function (w) w:set_mode("completion") end),
})

-- Return to command mode with original text and with original cursor position
function exit_completion(w)
    local state = data[w]
    w:enter_cmd(state.orig_text, { pos = state.orig_pos })
end

-- Command completion binds
add_binds("completion", {
    key({},          "Tab",    function (w) w.menu:move_down() end),
    key({"Shift"},   "Tab",    function (w) w.menu:move_up()   end),
    key({},          "Up",     function (w) w.menu:move_up()   end),
    key({},          "Down",   function (w) w.menu:move_down() end),
    key({},          "Escape", exit_completion),
    key({"Control"}, "[",      exit_completion),
})

function update_completions(w, text, pos)
    local state = data[w]

    -- Other parts of the code are triggering input changed events
    if state.lock then return end

    local input = w.ibar.input
    local text, pos = text or input.text, pos or input.position

    -- Don't rebuild the menu if the text & cursor position are the same
    if text == state.text and pos == state.pos then return end

    -- Exit completion if cursor outside a word
    if string.sub(text, pos, pos) == " " then
        w:enter_cmd(text, { pos = pos })
    end

    -- Update left and right strings
    state.text, state.pos = text, pos
    state.left = string.sub(text, 2, pos)
    state.right = string.sub(text, pos + 1)

    -- Call each completion function
    local groups = {}
    for _, func in ipairs(_M.order) do
        table.insert(groups, func(state) or {})
    end
    -- Join all result tables
    rows = lousy.util.table.join(unpack(groups))

    if rows[1] then
        -- Prevent callbacks triggering recursive updates.
        state.lock = true
        w.menu:build(rows)
        w.menu:show()
        if not state.built then
            state.built = true
            if rows[2] then w.menu:move_down() end
        end
        state.lock = false
    elseif not state.built then
        exit_completion(w)
    else
        w.menu:hide()
    end
end

new_mode("completion", {
    enter = function (w)
        -- Clear state
        local state = {}
        data[w] = state

        -- Save original text and cursor position
        local input = w.ibar.input
        state.orig_text = input.text
        state.orig_pos = input.position

        -- Update input text when scrolling through completion menu items
        w.menu:add_signal("changed", function (m, row)
            state.lock = true
            if row then
                input.text = row.left .. " " .. state.right
                input.position = #row.left
            else
                input.text = state.orig_text
                input.position = state.orig_pos
            end
            state.lock = false
        end)

        update_completions(w)
    end,

    changed = function (w, text)
        if not data[w].lock then
            update_completions(w, text)
        end
    end,

    move_cursor = function (w, pos)
        if not data[w].lock then
            update_completions(w, nil, pos)
        end
    end,

    leave = function (w)
        w.menu:hide()
        w.menu:remove_signals("changed")
    end,

    activate = function (w, text)
        local pos = w.ibar.input.position
        if string.sub(text, pos+1, pos+1) == " " then pos = pos+1 end
        w:enter_cmd(text, { pos = pos })
    end,
})

-- Completion functions
funcs = {
    -- Add command completion items to the menu
    command = function (state)
        -- We are only interested in the first word
        if string.match(state.left, "%s") then return end
        -- Check each command binding for matches
        local pat = "^" .. state.left
        local cmds = {}
        for _, b in ipairs(get_mode("command").binds) do
            if b.cmds then
                for i, cmd in ipairs(b.cmds) do
                    if string.match(cmd, pat) then
                        if i == 1 then
                            cmd = ":" .. cmd
                        else
                            cmd = string.format(":%s (:%s)", cmd, b.cmds[1])
                        end
                        cmds[cmd] = { escape(cmd), left = ":" .. b.cmds[1] }
                        break
                    end
                end
            end
        end
        -- Sort commands
        local keys = lousy.util.table.keys(cmds)
        -- Return if no results
        if not keys[1] then return end
        -- Build completion menu items
        local ret = {{ "Commands", title = true }}
        for _, cmd in ipairs(keys) do
            table.insert(ret, cmds[cmd])
        end
        return ret
    end,

    -- Add history completion items to the menu
    history = function (state)
        -- Find word under cursor (also checks not first word)
        local term = string.match(state.left, "%s(%S+)$")
        if not term then return end

        -- Build query & sort results by number of times visited
        local glob = sql_escape("*" .. string.lower(term) .. "*")

        -- Build SQL query
        local results = history.db:exec(string.format([[SELECT uri, title
            FROM history WHERE lower(uri) GLOB %s OR lower(title) GLOB %s
            ORDER BY visits DESC LIMIT 25;]], glob, glob))

        -- Return if no history items matched
        if not results[1] then return end

        -- Strip last word (so that we can append the completion uri)
        local left = ":" .. string.sub(state.left, 1,
            string.find(state.left, "%s(%S+)$"))

        -- Build rows
        local ret = {{ "History", "URI", title = true }}
        for _, row in ipairs(results) do
            table.insert(ret, { escape(row.title), escape(row.uri),
                left = left .. row.uri })
        end
        return ret
    end,
}

-- Order of completion items
order = {
    funcs.command,
    funcs.history,
}

-- vim: et:sw=4:ts=8:sts=4:tw=80
