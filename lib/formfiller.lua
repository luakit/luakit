-----------------------------------------------------------------
-- Luakit formfiller                                           --
-- © 2011 Fabian Streitel (karottenreibe) <k@rottenrei.be>     --
-- © 2011 Mason Larobina  (mason-l) <mason.larobina@gmail.com> --
-----------------------------------------------------------------

local lousy = require("lousy")
local string = string
local io = io
local loadstring, pcall = loadstring, pcall
local setfenv = setfenv
local capi = {
    luakit = luakit
}

local new_mode, add_binds = new_mode, add_binds

--- Provides functionaliy to auto-fill forms based on a Lua DSL
module("formfiller")

-- The formfiller rules
local rules = {}

-- The Lua DSL file containing the formfiller rules
local file = capi.luakit.data_dir .. "/formfiller.lua"

-- Reads the rules from the formfiller DSL file
function init()
    -- the environment of the DSL script
    local env = {}
    -- load the script
    local f = io.open(file, "r")
    local code = f:read("*all")
    f:close()
    local dsl, message = loadstring(code)
    if not dsl then
        warn(string.format("loading formfiller data failed: %s", message))
        return
    end
    -- execute in sandbox
    setfenv(dsl, env)
    rules = pcall(dsl)
end

--- Adds a new entry to the formfiller based on the current webpage.
function add(w)
end

--- Edits the formfiller rules.
function edit(w)
end

--- Fills the current page from the formfiller rules.
function fill(w)
end


-- Initialize the formfiller
init()

-- Add formfiller mode
new_mode("formfiller", {
    leave = function (w)
        w.menu:hide()
    end,
})

-- Setup formfiller binds
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^za$", add),
    buf("^ze$", edit),
    buf("^zl$", fill),
})

