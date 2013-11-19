package.path = package.path .. ";./config/?.lua;./lib/lousy/?.lua"
require "lunit"
require "util"
require "globals"

module("test_config_globals", lunit.testcase, package.seeall)


function test_globals()
  assert_table(globals)
end

function test_useragent()
  local originalversion = luakit.version

  local version_patterns = {}
  version_patterns["2012.09.13-r1-32-g993d814"] = "luakit/2012%.09%.13$"
  version_patterns["0d5f4ab"] = "luakit$"

  for v, p in pairs(version_patterns) do
    luakit.version = v
    package.loaded.globals = nil
    require "globals"
    assert_match(p, globals.useragent)
  end

  luakit.version = originalversion
end

