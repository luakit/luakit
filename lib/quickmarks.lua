----------------------------------------------------------------
-- Vimperator style quickmarking                              --
-- @author Piotr Husiatyński &lt;phusiatynski@gmail.com&gt;   --
-- @author Mason Larobina    &lt;mason.larobina@gmail.com&gt; --
----------------------------------------------------------------

-- Prepare local environment
local os = os
local io = io
local assert = assert
local string = string
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local type = type
local table = table
local util = lousy.util
local capi = { luakit = luakit }

module("quickmarks")

local quickmarks
local quickmarks_file = capi.luakit.data_dir .. '/quickmarks'

local function check_token(token)
    assert(string.match(tostring(token), "^(%w)$"), "invalid token: " .. tostring(token))
    return token
end

--- Load quick bookmarks from storage file into memory
-- @param fd_name bookmarks storage file path of nil to use default one
function load(fd_name)
    if not quickmarks then quickmarks = {} end

    local fd_name = fd_name or quickmarks_file
    if not os.exists(fd_name) then return end

    for line in io.lines(fd_name) do
        local token, uris = string.match(util.string.strip(line), "^(%w)%s+(.+)$")
        if token then
            quickmarks[token] = util.string.split(uris, ",%s+")
        end
    end
end

--- Save quick bookmarks to file
-- @param fd_name bookmarks storage file path of nil to use default one
function save(fd_name)
    -- Quickmarks init check
    if not quickmarks then load() end

    local fd = io.open(fd_name or quickmarks_file, "w")
    for _, token in ipairs(util.table.keys(quickmarks)) do
        local uris = table.concat(quickmarks[token], ", ")
        fd:write(string.format("%s %s\n", token, uris))
    end
    io.close(fd)
end

--- Return url related to given key or nil if does not exist
-- @param token quick bookmarks mapping token
-- @param load_file Call quickmark.load() before get
function get(token, load_file)
    -- Load quickmarks from other sessions
    if not quickmarks or load_file ~= false then load() end

    return quickmarks[check_token(token)]
end

--- Return a list of all the tokens in the quickmarks table
function get_tokens()
    if not quickmarks then load() end
    return util.table.keys(quickmarks)
end

--- Set new quick bookmarks mapping
-- @param token The token under which given uris will be available
-- @param uris List of locations to quickmark
-- @param load_file Call quickmark.load() before set
-- @param save_file Call quickmark.save() after set
function set(token, uris, load_file, save_file)
    -- Load quickmarks from other sessions
    if not quickmarks or load_file ~= false then load() end

    -- Parse uris: "http://forum1.com, google.com, imdb some artist"
    if uris and type(uris) == "string" then
        uris = util.string.split(uris, ",%s+")
    elseif uris and type(uris) ~= "table" then
        error("invalid locations type: ", type(uris))
    end

    quickmarks[check_token(token)] = uris

    -- By default, setting new quickmark saves them to
    if save_file ~= false then save() end
end

--- Delete a quickmark
-- @param token The quickmark token
-- @param load_file Call quickmark.load() before deletion
-- @param save_file Call quickmark.save() after deletion
function del(token, load_file, save_file)
    -- Load quickmarks from other sessions
    if not quickmarks or load_file ~= false then load() end

    quickmarks[check_token(token)] = nil
    if save_file ~= false then save() end
end

--- Delete all quickmarks
-- @param save_file Call quickmark.save() function.
function delall(save_file)
    quickmarks = {}
    if save_file ~= false then save() end
end
