local setfenv = setfenv
local print = print
local util = require("lousy.util")
local env = getfenv(getfenv)

--- Evaluates userscripts with a simple standard API to
-- deal wih common userscript problems.
module("userscripts")

local env = util.table.join(env, {})

--- Stores all the scripts.
local scripts = {}

--- The directory, in which to search for userscripts.
dir = util.find_data("/scripts")

--- Loads all userscripts from the <code>dir</code>.
function init()
end

