-- Save a reference to the original lua assert function
orig_assert = assert

-- Add ./lunit & ./tests to package.path
package.path = package.path .. ';./lunit/?.lua;./tests/?.lua'

require "lunit"
local stats = lunit.main(uris)
luakit.quit(stats.errors + stats.failed)
