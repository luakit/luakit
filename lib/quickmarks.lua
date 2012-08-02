----------------------------------------------------------------
-- Vimperator style quickmarking                              --
-- @author Piotr Husiatyński &lt;phusiatynski@gmail.com&gt;   --
-- @author Mason Larobina    &lt;mason.larobina@gmail.com&gt; --
----------------------------------------------------------------

-- Get lua environment
local os = os
local io = io
local assert = assert
local string = string
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local type = type
local table = table

-- Get luakit environment
local lousy = require "lousy"
local window = window
local add_binds, add_cmds = add_binds, add_cmds
local new_mode, menu_binds = new_mode, menu_binds
local capi = { luakit = luakit }

module("quickmarks")

local qmarks
local quickmarks_file = capi.luakit.data_dir .. '/quickmarks'

local function check_token(token)
    assert(string.match(tostring(token), "^(%w)$"), "invalid token: " .. tostring(token))
    return token
end

--- Load quick bookmarks from storage file into memory
-- @param fd_name bookmarks storage file path of nil to use default one
function load(fd_name)
    if not qmarks then qmarks = {} end

    local fd_name = fd_name or quickmarks_file
    if not os.exists(fd_name) then return end

    for line in io.lines(fd_name) do
        local token, uris = string.match(lousy.util.string.strip(line), "^(%w)%s+(.+)$")
        if token then
            qmarks [token] = lousy.util.string.split(uris, ",%s+")
        end
    end
end

--- Save quick bookmarks to file
-- @param fd_name bookmarks storage file path of nil to use default one
function save(fd_name)
    -- Quickmarks init check
    if not qmarks then load() end

    local fd = io.open(fd_name or quickmarks_file, "w")
    for _, token in ipairs(lousy.util.table.keys(qmarks )) do
        local uris = table.concat(qmarks [token], ", ")
        fd:write(string.format("%s %s\n", token, uris))
    end
    io.close(fd)
end

--- Return url related to given key or nil if does not exist
-- @param token quick bookmarks mapping token
-- @param load_file Call quickmark.load() before get
function get(token, load_file)
    -- Load quickmarks from other sessions
    if not qmarks or load_file ~= false then load() end

    return qmarks[check_token(token)]
end

--- Return a list of all the tokens in the quickmarks table
function get_tokens()
    if not qmarks then load() end
    return lousy.util.table.keys(qmarks )
end

--- Set new quick bookmarks mapping
-- @param token The token under which given uris will be available
-- @param uris List of locations to quickmark
-- @param load_file Call quickmark.load() before set
-- @param save_file Call quickmark.save() after set
function set(token, uris, load_file, save_file)
    -- Load quickmarks from other sessions
    if not qmarks or load_file ~= false then load() end

    -- Parse uris: "http://forum1.com, google.com, imdb some artist"
    if uris and type(uris) == "string" then
        uris = lousy.util.string.split(uris, ",%s+")
    elseif uris and type(uris) ~= "table" then
        error("invalid locations type: ", type(uris))
    end

    qmarks[check_token(token)] = uris

    -- By default, setting new quickmark saves them to
    if save_file ~= false then save() end
end

--- Delete a quickmark
-- @param token The quickmark token
-- @param load_file Call quickmark.load() before deletion
-- @param save_file Call quickmark.save() after deletion
function del(token, load_file, save_file)
    -- Load quickmarks from other sessions
    if not qmarks or load_file ~= false then load() end

    qmarks[check_token(token)] = nil
    if save_file ~= false then save() end
end

--- Delete all quickmarks
-- @param save_file Call quickmark.save() function.
function delall(save_file)
    qmarks = {}
    if save_file ~= false then save() end
end

-- Add quickmarking binds to normal mode
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^g[onw][a-zA-Z0-9]$",
        [[Jump to quickmark in current tab with `go{a-zA-Z0-9}`,
        `gn{a-zA-Z0-9}` to open in new tab and or `gw{a-zA-Z0-9}` to open a
        quickmark in a new window.]],
        function (w, b, m)
            local mode, token = string.match(b, "^g(.)(.)$")
            local uris = lousy.util.table.clone(get(token) or {})
            for i, uri in ipairs(uris) do uris[i] = w:search_open(uri) end
            for c=1,m.count do
                if mode == "w" then
                    window.new(uris)
                else
                    for i, uri in ipairs(uris or {}) do
                        if mode == "o" and c == 1 and i == 1 then w:navigate(uri)
                        else w:new_tab(uri, i == 1) end
                    end
                end
            end
        end, {count=1}),

    buf("^M[a-zA-Z0-9]$",
        [[Add quickmark for current URL.]],
        function (w, b)
            local token = string.match(b, "^M(.)$")
            local uri = w.view.uri
            set(token, {uri})
            w:notify(string.format("Quickmarked %q: %s", token, uri))
        end),
})

-- Add quickmarking commands
local cmd = lousy.bind.cmd
add_cmds({
    -- Quickmark add (`:qmark f http://forum1.com, forum2.com, imdb some artist`)
    cmd("qma[rk]", "Add a quickmark.", function (w, a)
        local token, uris = string.match(lousy.util.string.strip(a), "^(%w)%s+(.+)$")
        assert(token, "invalid token")
        uris = lousy.util.string.split(uris, ",%s+")
        set(token, uris)
        w:notify(string.format("Quickmarked %q: %s", token, table.concat(uris, ", ")))
    end),

    -- Quickmark edit (`:qmarkedit f` -> `:qmark f furi1, furi2, ..`)
    cmd({"qmarkedit", "qme"}, "Edit a quickmark.", function (w, a)
        token = lousy.util.string.strip(a)
        assert(#token == 1, "invalid token length: " .. token)
        local uris = get(token)
        w:enter_cmd(string.format(":qmark %s %s", token, table.concat(uris or {}, ", ")))
    end),

    -- Quickmark del (`:delqmarks b-p Aa z 4-9`)
    cmd("delqm[arks]", "Delete a quickmark.", function (w, a)
        -- Find and del all range specifiers
        string.gsub(a, "(%w%-%w)", function (range)
            range = "["..range.."]"
            for _, token in ipairs(get_tokens()) do
                if string.match(token, range) then del(token, false) end
            end
        end)
        -- Delete lone tokens
        string.gsub(a, "(%w)", function (token) del(token, false) end)
        save()
    end),

    -- View all quickmarks in an interactive menu
    cmd("qmarks", "List all quickmarks.", function (w) w:set_mode("qmarklist") end),

    -- Delete all quickmarks
    cmd({"delqmarks!", "delqm!"}, "Delete all quickmarks.", function (w) delall() end),
})

-- Add mode to display all quickmarks in an interactive menu
new_mode("qmarklist", {
    enter = function (w)
        local rows = {{ "Quickmarks", " URI(s)", title = true }}
        for _, qmark in ipairs(get_tokens()) do
            local uris = lousy.util.escape(table.concat(get(qmark, false), ", "))
            table.insert(rows, { "  " .. qmark, " " .. uris, qmark = qmark })
        end
        w.menu:build(rows)
        w:notify("Use j/k to move, d delete, e edit, t tabopen, w winopen.", false)
    end,

    leave = function (w)
        w.menu:hide()
    end,
})

-- Add additional binds to quickmarks menu mode
local key = lousy.bind.key
add_binds("qmarklist", lousy.util.table.join({
    -- Delete quickmark
    key({}, "d", function (w)
        local row = w.menu:get()
        if row and row.qmark then
            del(row.qmark)
            w.menu:del()
        end
    end),

    -- Edit quickmark
    key({}, "e", function (w)
        local row = w.menu:get()
        if row and row.qmark then
            local uris = get(row.qmark)
            w:enter_cmd(string.format(":qmark %s %s",
                row.qmark, table.concat(uris or {}, ", ")))
        end
    end),

    -- Open quickmark
    key({}, "Return", function (w)
        local row = w.menu:get()
        if row and row.qmark then
            for i, uri in ipairs(get(row.qmark) or {}) do
                uri = w:search_open(uri)
                if i == 1 then w:navigate(uri) else w:new_tab(uri, false) end
            end
        end
    end),

    -- Open quickmark in new tab
    key({}, "t", function (w)
        local row = w.menu:get()
        if row and row.qmark then
            for _, uri in ipairs(get(row.qmark) or {}) do
                w:new_tab(w:search_open(uri), false)
            end
        end
    end),

    -- Open quickmark in new window
    key({}, "w", function (w)
        local row = w.menu:get()
        w:set_mode()
        if row and row.qmark then
            window.new(get(row.qmark) or {})
        end
    end),

    -- Exit menu
    key({}, "q", function (w) w:set_mode() end),

}, menu_binds))

-- vim: et:sw=4:ts=8:sts=4:tw=80
