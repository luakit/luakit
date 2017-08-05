--- Command completion.
--
-- This module provides tab completion for luakit commands. Currently, it
-- supports completing URLs from the user's bookmarks and history, and also
-- supports completing partially typed commands.
--
-- @module completion
-- @copyright 2010-2011 Mason Larobina  <mason.larobina@gmail.com>
-- @copyright 2010 Fabian Streitel <karottenreibe@gmail.com>

local lousy = require("lousy")
local history = require("history")
local bookmarks = require("bookmarks")
local modes = require("modes")
local new_mode, get_mode = modes.new_mode, modes.get_mode
local add_binds = modes.add_binds
local escape = lousy.util.escape

local _M = {}

-- Store completion state (indexed by window)
local data = setmetatable({}, { __mode = "k" })

-- Add completion start trigger
add_binds("command", {
    { "<Tab>", "Open completion menu.", function (w) w:set_mode("completion") end },
})

--- Return to command mode with original text and with original cursor position.
function _M.exit_completion(w)
    local state = data[w]
    w:enter_cmd(state.orig_text, { pos = state.orig_pos })
end

--- Update the list of completions for some input text.
-- @tparam table w The current window table.
-- @tparam string text The current input text.
-- @tparam number pos The current input cursor position.
function _M.update_completions(w, text, pos)
    local state = data[w]

    -- Other parts of the code are triggering input changed events
    if state.lock then return end

    local input = w.ibar.input
    text, pos = text or input.text, pos or input.position

    -- Don't rebuild the menu if the text & cursor position are the same
    if text == state.text and pos == state.pos then return end

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
    local rows = lousy.util.table.join(unpack(groups))

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
        _M.exit_completion(w)
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
        w.menu:add_signal("changed", function (_, row)
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

        _M.update_completions(w)
    end,

    changed = function (w, text)
        if not data[w].lock then
            local input = w.ibar.input
            data[w].orig_text = input.text
            data[w].orig_pos = input.position
            _M.update_completions(w, text)
        end
    end,

    move_cursor = function (w, pos)
        if not data[w].lock then
            _M.update_completions(w, nil, pos)
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

-- Command completion binds
add_binds("completion", {
    { "<Tab>", "Select next matching completion item.",
        function (w) w.menu:move_down() end },
    { "<Shift-Tab>", "Select previous matching completion item.",
        function (w) w.menu:move_up() end },
    { "Up", "Select next matching completion item.",
        function (w) w.menu:move_up() end },
    { "Down", "Select previous matching completion item.",
        function (w) w.menu:move_down() end },
    { "<Control-j>", "Select next matching completion item.",
        function (w) w.menu:move_down() end },
    { "<Control-k>", "Select previous matching completion item.",
        function (w) w.menu:move_up() end },
    { "<Escape>", "Stop completion and restore original command.",
        _M.exit_completion },
    { "<Control-[>", "Stop completion and restore original command.",
        _M.exit_completion },
})

local completion_funcs = {
    -- Add command completion items to the menu
    command = function (state)
        -- We are only interested in the first word
        if string.match(state.left, "%s") then return end
        -- Check each command binding for matches
        local pat = state.left
        local cmds = {}
        for _, m in ipairs(get_mode("command").binds) do
            local b = m[1]
            if m.cmds or (b and b:match("^:")) then
                local c = m.cmds or {}
                if not m.cmds then
                    for _, cmd in ipairs(lousy.util.string.split(b:gsub("^:", ""), ",%s+:")) do
                        if string.match(cmd, "^([%-%w]+)%[(%w+)%]") then
                            local l, r = string.match(cmd, "^([%-%w]+)%[(%w+)%]")
                            table.insert(c, l..r)
                            table.insert(c, l)
                        else
                            table.insert(c, cmd)
                        end
                    end
                end

                for i, cmd in ipairs(c) do
                    if string.find(cmd, pat, 1, true) == 1 then
                        if i == 1 then
                            cmd = ":" .. cmd
                        else
                            cmd = string.format(":%s (:%s)", cmd, c[1])
                        end

                        cmds[cmd] = { escape(cmd), escape(m[2].desc) or "", left = ":" .. c[1] }
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
        local ret = {{ "Command", "Description", title = true }}
        for _, cmd in ipairs(keys) do
            table.insert(ret, cmds[cmd])
        end
        return ret
    end,

    -- Add history completion items to the menu
    history = function (state)
        -- Split into prefix and search term
        local split = string.find(state.left, "%s")
        if not split then return end
        local prefix = ":" .. string.sub(state.left, 1, split)
        local term = string.sub(state.left, split+1)
        if not term or term == "" then return end

        local sql = [[
            SELECT uri, title, lower(uri||title) AS text
            FROM history WHERE text GLOB ?
            ORDER BY visits DESC LIMIT 25
        ]]

        local rows = history.db:exec(sql, { string.format("*%s*", term) })
        if not rows[1] then return end

        -- Strip everything but the prefix (so that we can append the completion uri)
        local left = prefix

        -- Build rows
        local ret = {{ "History", "URI", title = true }}
        for _, row in ipairs(rows) do
            table.insert(ret, { escape(row.title), escape(row.uri),
                left = left .. row.uri })
        end
        return ret
    end,

    -- add bookmarks completion to the menu
    bookmarks = function (state)
        -- Split into prefix and search term
        local split = string.find(state.left, "%s")
        if not split then return end
        local prefix = ":" .. string.sub(state.left, 1, split)
        local term = string.sub(state.left, split+1)
        if not term or term == "" then return end

        local sql = [[
            SELECT uri, title, lower(uri||title||tags) AS text
            FROM bookmarks WHERE text GLOB ?
            ORDER BY title DESC LIMIT 25
        ]]

        local rows = bookmarks.db:exec(sql, { string.format("*%s*", term) })
        if not rows[1] then return end

        -- Strip everything but the prefix (so that we can append the completion uri)
        local left = prefix

        -- Build rows
        local ret = {{ "Bookmarks", "URI", title = true }}
        for _, row in ipairs(rows) do
            local title = row.title ~= "" and row.title or row.uri
            table.insert(ret, { escape(title), escape(row.uri),
                left = left .. row.uri })
        end
        return ret
    end,
}

--- Table of functions used to generate completion entries.
-- @readonly
_M.funcs = {
    command = completion_funcs.command,
    -- Completes commands.
    history = completion_funcs.history,
    -- Completes URIs present in the user's history.
    bookmarks = completion_funcs.bookmarks,
    -- Completes URIs that have been bookmarked.
}

--- Array of completion functions from @ref{funcs}, called in order.
-- @readwrite
_M.order = {
    [1] = _M.funcs.command, -- `funcs.command`
    [2] = _M.funcs.history, -- `funcs.history`
    [3] = _M.funcs.bookmarks, -- `funcs.bookmarks`
}

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
