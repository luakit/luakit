local string = string
local webview = webview
local util = require("lousy.util")
local env = getfenv(getfenv)
local lfs = require("lfs")
local loadfile = loadfile
local table = table
local pairs = pairs
local io = io
local os = os
local type = type
local luakit = luakit

--- Evaluates and manages userscripts.
-- A userscript is either
-- a)   A lua script that returns a table representing a userscript.
--      The table needs to contain the following keys:
--      *   include     An array of patterns that match URI's, for
--                      which the script should be loaded.
--      *   exclude     An array of patterns that match URI's, for
--                      which the script should not be loaded.
--      *   script      The script itself. It will get the current window
--                      and webview as it's parameters.
--      Lua userscripts must end in <code>.user.lua</code>
-- b)   A traditional userscript.
--      JavaScript userscripts must end in <code>.user.js</code>
module("userscripts")

--- Stores all the scripts.
local scripts = {}

--- The directory, in which to search for userscripts.
-- By default, this is $XDG_DATA_HOME/scripts
dir = luakit.data_dir .. "/scripts"

--- Loads a lua userscript.
local function load_lua(file)
    fun, msg = loadfile(file)
    if fun then
        -- get metadata
        script = fun()
        script.file = file
        table.insert(scripts, script)
    else
        io.stderr:write(msg .. "\n")
    end
end

--- Extracts and converts all URI patterns of the given type (include, exclude)
-- from the userscript pattern syntax to lua patterns.
local function all_matches(str, typ)
    local pat = "//%s*@" .. typ .. "%s*([^\r\n]*)"
    local arr = {}
    for p in string.gmatch(str, pat) do
        -- escape [%.$?^] and convert * into .*
        p = string.gsub(string.gsub(p, "[%%.?$^]", "%%%1"), "*", ".*")
        --p = string.format("^%s$", p)
        table.insert(arr, p)
    end
    return arr
end

--- Loads a js userscript.
local function load_js(file)
    local f = io.open(file, "r")
    local js = f:read("*all")
    f:close()

    local header = string.match(js, "//%s*==UserScript==.*\n//%s*==/UserScript==")
    if header then
        local include = all_matches(header, "include")
        local exclude = all_matches(header, "exclude")
        local fun = function(w, v) v:eval_js(js, string.format("(userscript:%s)", file)) end
        script = {name=name,include=include,exclude=exclude,script=fun,file=file}
        table.insert(scripts, script)
    end
end

--- Loads all userscripts from the <code>userscripts.dir</code>.
local function init()
    if os.exists(dir) then
        for f in lfs.dir(dir) do
            if string.match(f, "%.user%.lua$") then
                load_lua(dir .. "/" .. f)
            elseif string.match(f, "%.user%.js$") then
                load_js(dir .. "/" .. f)
            end
        end
    end
end

--- Tests if the given uri is matched by the given script.
local function included(s, uri)
    local included = false
    if s.include and type(s.include) == "table" then
        for _,i in pairs(s.include) do
            if i and string.match(uri, i) then
                included = true
                break
            end
        end
    end
    if s.exclude and type(s.exclude) == "table" then
        for _,i in pairs(s.exclude) do
            if i and string.match(uri, i) then
                included = false
                break
            end
        end
    end
    return included
end

--- Invokes all userscripts for the given uri, passing them the given
-- window and view.
local function invoke(w, v, uri)
    for _,s in pairs(scripts) do
        if included(s, uri) then
            local fun = s.script and type(s.script) == "function" and s.script
            if fun then fun(w, v) end
        end
    end
end

--- Hook on the webview's load-status signal to invoke the userscripts.
webview.init_funcs.userscripts = function (view, w)
    view:add_signal("load-status", function (v, status)
        if status ~= "finished" then return end
        local uri = v.uri or "about:blank"
        invoke(w, v, uri)
    end)
end

-- Initialize the userscripts
init()

