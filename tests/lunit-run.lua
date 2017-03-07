-- Add ./lunit & ./tests to package.path
package.path = package.path .. ';./lunit/?.lua;./tests/?.lua'

local lunit = require "lunit"
local stats = lunit.main(uris)
luakit.quit(stats.errors + stats.failed)

-- vim: et:sw=4:ts=8:sts=4:tw=80
