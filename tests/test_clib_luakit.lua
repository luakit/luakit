require "lunit"

module("test_clib_luakit", lunit.testcase, package.seeall)

function test_luakit()
    assert_table(luakit)
    -- Check metatable
    mt = getmetatable(luakit)
    assert_function(mt.__index, "luakit mt missing __index")
end

function test_luakit_index()
    local funcprops = { "exec", "quit", "save_file", "spawn", "spawn_sync",
        "time", "uri_decode", "uri_encode", "idle_add", "idle_remove" }
    for _, p in ipairs(funcprops) do
        assert_function(luakit[p], "Missing/invalid function: luakit."..p)
    end

    local strprops = { "cache_dir", "config_dir", "data_dir", "execpath",
        "confpath", "install_path", "version" }
    for _, p in ipairs(strprops) do
        assert_string(luakit[p], "Missing/invalid property: luakit."..p)
    end

    local boolprops = { "dev_paths", "verbose", "nounique" }
    for _, p in ipairs(boolprops) do
        assert_boolean(luakit[p], "Missing/invalid property: luakit."..p)
    end

    assert_number(luakit.time(), "Invalid: luakit.time()")
end

function test_webkit_version()
    assert_match("^%d+%.%d+%.%d$", luakit.webkit_version,
        "Invalid format: luakit.webkit_version")
    assert_match("^%d+%.%d+$", luakit.webkit_user_agent_version,
        "Invalid format: luakit.webkit_user_agent_version")
end

function test_windows_table()
    assert_table(luakit.windows, "Missing/invalid luakit.windows table.")
    assert_equal(#luakit.windows, 0, "Invalid number of windows")
    win = widget{type="window"}
    assert_equal(#luakit.windows, 1,
        "luakit.windows not tracking opened windows.")
    win:destroy()
    assert_equal(#luakit.windows, 0,
        "luakit.windows not tracking closed windows.")
end

function test_invalid_prop()
    assert_nil(luakit.invalid_property)
end

function test_idle_add_del()
    local f = function () end
    assert_false(luakit.idle_remove(f),
        "Function can't be removed before it's been added.")
    for i = 1,5 do
        luakit.idle_add(f)
    end
    for i = 1,5 do
        assert_true(luakit.idle_remove(f), "Error removing callback.")
    end
    assert_false(luakit.idle_remove(f),
        "idle_remove removed incorrect number of callbacks.")
end
