local setfenv = setfenv
local print = print
local util = require("lousy.util")
local env = getfenv(getfenv)
local lfs = require("lfs")
local loadfile = loadfile
local table = table

--- Evaluates and manages userscripts.
-- A userscript is either
-- a)   A lua script that returns a table representing a userscript.
-- b)   A traditional userscript.
module("userscripts")

local env = util.table.join(env, {})

--- Stores all the scripts.
local scripts = {}

--- The directory, in which to search for userscripts.
dir = util.find_data("/scripts")

--- Loads all userscripts from the <code>userscripts.dir</code>.
local function init()
    for f in lfs.dir(dir) do
        if string.match(f, "\.lua$") then
            -- load lua script
            fun, msg = loadfile(dir .. "/" .. f)
            if fun then
                -- get metadata
                script = fun()
                table.insert(scripts, script)
            else
                io.stderr:write(msg .. "\n")
            end
        elseif string.match(f, "\.user\.js$") then
            -- load js script
            -- TODO
        end
    end
end

--- Tests if the given uri is matched by the given script.
local function included(s, uri)
    local included = false
    if s.include then
        for _,i in s.include do
            if i and string.match(uri, i) then
                included = true
                break
            end
        end
    end
    if s.exclude then
        for _,i in s.exclude do
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
            local fun = s.fun
            setfenv(fun, env)
            fun(w, v)
        end
    end
end

--- Hook on the webview's load-status signal to invoke the userscripts.
webview.init_funcs.userscripts = function (view, w)
    view:add_signal("load-status", function (v, status)
        if status ~= "committed" then return end
        local uri = v.uri or "about:blank"
        invoke(w, v, uri)
    end)
end

-- Initialize the userscripts
init()

