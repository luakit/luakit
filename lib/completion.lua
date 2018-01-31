--- Command completion.
--
-- This module provides tab completion for luakit commands. Currently, it
-- supports completing URLs from the user's bookmarks and history, and also
-- supports completing partially typed commands.
--
-- @module completion
-- @copyright 2010-2011 Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2010 Fabian Streitel <karottenreibe@gmail.com>

local lousy = require("lousy")
local history = require("history")
local bookmarks = require("bookmarks")
local modes = require("modes")
local settings = require("settings")
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
    w:enter_cmd(state.orig_text)
end

local parse_completion_format = function (fmt)
    if type(fmt) == "table" then return fmt end
    local parts, ret = lousy.util.string.split(fmt, "%s+"), {}
    for i, part in ipairs(parts) do
        local grp = part:match("^{([%w-]+)}$")
        if i > 1 then ret[#ret+1] = { lit = "%s+", pattern = true } end
        ret[#ret+1] = grp and { grp = grp } or { lit = part }
    end
    return ret
end

local completers = {}

local function parse(buf)
    local function match_step (state, matches)
        local new_states = {}

        for _, s in ipairs(state) do
            local nup = s[s.pos] -- next unmatched part
            if not nup then -- fully parsed
                table.insert(matches.full, s)
            elseif nup.lit then -- literal (with possible %s+)
                local m = nup.pattern and s.buf:match(nup.lit) or (s.buf:find(nup.lit, 1, true) and nup.lit or nil)
                if not m then
                    if #s.buf < #nup.lit and nup.lit:sub(1,#s.buf) == s.buf then
                        table.insert(matches.partial, s)
                    end
                else
                    table.insert(new_states, lousy.util.table.join(s, { buf = s.buf:sub(#m+1), pos = s.pos+1 }))
                end
            elseif nup.grp then -- completion group name
                local cgroup = assert(completers[nup.grp], "No completion group '".. nup.grp .. "'")
                local cresults = assert(cgroup.func(s.buf))

                for _, cr in ipairs(cresults) do
                    local crf = type(cr) == "table" and cr.format or cr
                    local parts = parse_completion_format(crf)
                    local ns = lousy.util.table.join(s)
                    -- Replace current completion part with all returned parts
                    table.remove(ns, ns.pos)
                    for i, part in ipairs(parts) do table.insert(ns, ns.pos+i-1, part) end
                    ns[ns.pos].row = cr
                    ns[ns.pos].orig_grp = nup.grp

                    if cr.buf then
                        -- to complete from this state, we need to change the buffer
                        -- so it's a partial match
                        ns.buf = cr.buf
                        table.insert(matches.partial, ns)
                    else
                        table.insert(new_states, ns)
                    end
                end

            else
                error "Bad parsing part (expected lit or grp)"
            end
        end
        return new_states
    end

    -- Generate completion options with format strings
    local matches = { full = {}, partial = {} }
    local states = {{
        { lit = ":"}, { grp = "command" },
        buf = buf,
        pos = 1,
    }}
    repeat
        states = match_step(states, matches)
    until #states == 0

    return matches
end

local function complete(buf)
    local matches, rows = parse(buf).partial, {}
    local pat2lit = function (p) return p == "%s+" and " " or p end
    local prev_grp

    for _, m in ipairs(matches) do
        if m[m.pos].lit == "%s+" and m.pos > 1 then m.pos = m.pos-1 end

        local grp = m[m.pos].orig_grp
        if prev_grp ~= grp then
            prev_grp = grp
            table.insert(rows, lousy.util.table.join(completers[grp].header, { title = true }))
        end

        local whole = ""
        for i=1,m.pos do whole = whole .. pat2lit(m[i].lit) end
        table.insert(rows, { m[m.pos].row[1], m[m.pos].row[2], text = whole })
    end
    return rows
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

    if pos ~= #text then _M.exit_completion(w) return end

    -- Don't rebuild the menu if the text & cursor position are the same
    if text == state.text and pos == state.pos then return end

    -- Update left and right strings
    state.text, state.pos = text, pos

    local rows = complete(text)

    if rows[2] then
        -- Prevent callbacks triggering recursive updates.
        state.lock = true
        w.menu:build(rows)
        w.menu:show()
        if not state.built then
            state.built = true
            if rows[2] then w.menu:move_down() end
        end
        state.lock = false
    else
        _M.exit_completion(w)
    end
end

local function input_change_cb (w)
    if not data[w].lock then
        local input = w.ibar.input
        data[w].orig_text = input.text
        data[w].orig_pos = input.position
        _M.update_completions(w)
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
                input.text = row.text
                input.position = #row.text
            else
                input.text = state.orig_text
                input.position = state.orig_pos
            end
            state.lock = false
        end)

        _M.update_completions(w)
    end,

    changed = input_change_cb,
    move_cursor = input_change_cb,

    leave = function (w)
        w.menu:hide()
        w.menu:remove_signals("changed")
    end,

    activate = function (w, text)
        _M.exit_completion(w)
        w:enter_cmd(text)
        w:activate()
    end,
})

-- Command completion binds
add_binds("completion", {
    { "<Tab>", "Select next matching completion item.",
        function (w) w.menu:move_down() end },
    { "<Shift-Tab>", "Select previous matching completion item.",
        function (w) w.menu:move_up() end },
    { "<Up>", "Select next matching completion item.",
        function (w) w.menu:move_up() end },
    { "<Down>", "Select previous matching completion item.",
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

completers.command = {
    header = { "Command", "Description" },
    func = function (rem)
        local prefix, rets = rem:match("^([%w-]*)"), {}

        -- Check each command binding for matches
        local cmds = {}
        for _, m in ipairs(get_mode("command").binds) do
            local b, a = unpack(m)
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
                    if string.find(cmd, prefix, 1, true) == 1 then
                        if i == 1 then
                            cmd = ":" .. cmd
                        else
                            cmd = string.format(":%s (:%s)", cmd, c[1])
                        end

                        local format = c[1] .. (a.format and (" "..a.format) or "")
                        cmds[cmd] = { escape(cmd), escape(m[2].desc) or "", format = format }
                        break
                    end
                end
            end
        end

        local keys = lousy.util.table.keys(cmds)
        for _, k in ipairs(keys) do
            rets[#rets+1] = cmds[k]
        end
        return rets
    end,
}

local function sql_like_globber(term)
    local escaped = term:gsub("[\\%%_]", { ["\\"] = "\\\\", ["%"] = "\\%", ["_"] = "\\_" })
    return "%" .. escaped:gsub("%s+", "%%") .. "%"
end

settings.register_settings({
    ["completion.history.order"] = {
        type = "string",
        default = "visits",
        desc = [=[
            A string indicating how history items should be sorted in
            completion. Possible values are:

            - `visits`: most visited websites first
            - `last_visit`: most recent websites first
            - `title`: sort by title, alphabetically
            - `uri`: sort by website address, alphabetically
        ]=],
        validator = function (v)
            local t = {visits = true, last_visit = true, title = true, uri = true}
            return t[v]
        end
    },
    ["completion.max_items"] = {
        type = "number", min = 1,
        default = 25,
        desc = "Number of completion items for history and bookmarks."
    }
})

completers.history = {
    header = { "History", "URI" },
    func = function (buf)
        local order = settings.get_setting("completion.history.order")
        local desc = (order == "visits" or order == "last_visit") and " DESC" or ""
        local term, ret, sql = buf, {}, [[
            SELECT uri, title, lower(uri||ifnull(title,'')) AS text
            FROM history WHERE text LIKE ? ESCAPE '\'
            ORDER BY
        ]] .. order .. desc .. " LIMIT " .. settings.get_setting("completion.max_items")

        local rows = history.db:exec(sql, { sql_like_globber(term) })
        if not rows[1] then return {} end

        for _, row in ipairs(rows) do
            table.insert(ret, {
                escape(row.title) or "", escape(row.uri),
                format = {{ lit = row.uri }},
                buf = row.uri
            })
        end
        return ret
    end,
}

completers.bookmarks = {
    header = { "Bookmarks", "URI" },
    func = function (buf)
        local term, ret, sql = buf, {}, [[
            SELECT uri, title, lower(uri||ifnull(title,'')||ifnull(tags,'')) AS text
            FROM bookmarks WHERE text LIKE ? ESCAPE '\'
            ORDER BY title DESC LIMIT
        ]] .. settings.get_setting("completion.max_items")

        local rows = bookmarks.db:exec(sql, { sql_like_globber(term) })
        if not rows[1] then return {} end

        for _, row in ipairs(rows) do
            local title = row.title ~= "" and row.title or row.uri
            table.insert(ret, {
                escape(title), escape(row.uri),
                format = {{ lit = row.uri }},
                buf = row.uri
            })
        end
        return ret
    end,
}

completers.uri = {
    func = function () return { { format = "{history}" }, { format = "{bookmarks}" }, } end,
}

completers.setting = {
    header = { "Setting", "Current value" },
    func = function ()
        local ret = {}
        for key, setting in pairs(settings.get_settings()) do
            table.insert(ret, {
                key, tostring(setting.value),
                format = key,
            })
        end
        return ret
    end,
}

completers.domain = {
    header = { "Domain", "" },
    func = function (buf)
        local prefix = buf:match("^%S+")
        return prefix and {{ prefix, "", format = {{ lit = prefix }} }} or {}
    end,
}

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
