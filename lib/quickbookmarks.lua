---------------------------------------------------------------------------
-- @author Piotr Husiatyński &ly;phusiatynski@gmail.com&gt;
---------------------------------------------------------------------------


-- Prepare local environment
local capi = { luakit = luakit }
local io = io
local os = os
local tostring = tostring
local pairs = pairs
local string = string

local quickbookmarks = {}
local quickbookmarks_file = capi.luakit.data_dir .. '/quickbookmarks'


module("quickbookmarks")


--- Load quick bookmarks from storage file into memory
-- @param fd_name bookmarks storage file path of nil to use default one
function load(fd_name)
    local fd_name = fd_name or quickbookmarks_file

    -- if file does not exists yet, do nothing
    if not os.exists(fd_name) then
        return
    end

    for line in io.lines(fd_name) do
        line:gsub("([^%s])\ +(.+)", function(token, url)
            quickbookmarks[token] = url
        end)
    end
end

--- Save quick bookmarks to file
-- @param fd_name bookmarks storage file path of nil to use default one
function save(fd_name)
    local fd_name = fd_name or quickbookmarks_file
    local fd = io.open(fd_name, "w")

    -- rewrite quick bookmarks file with current bookmarks table
    for key, value in pairs(quickbookmarks) do
        local line = string.format("%s    %s\n", key, value)
        fd:write(line)
    end

    io.close(fd)
end

--- Return url related to given key or nil if does not exist
-- @param token quick bookmarks mapping token
function get_url(token)
    -- strip token
    local token = string.gsub(token, "^%s*(.-)%s*$", "%1")

    return quickbookmarks[tostring(token)]
end

--- Set new quick bookmarks mapping
-- @param token token under which given url will be available
-- @param url url related to given token
function set_url(token, url, save_file)
    -- strip both token and url
    local token = string.gsub(token, "^%s*(.-)%s*$", "%1")
    local url = string.gsub(url, "^%s*(.-)%s*$", "%1")

    quickbookmarks[token] = url

    -- by default, setting new url mapping always saves to file
    if save_file ~= false then
        save()
    end
end
