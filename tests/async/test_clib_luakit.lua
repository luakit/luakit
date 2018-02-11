--- Test luakit clib functionality.
--
-- @copyright 2012 Mason Larobina <mason.larobina@gmail.com>

local assert = require "luassert"
local test = require "tests.lib"

local T = {}

T.test_luakit = function ()
    assert.is_table(luakit)
    -- Check metatable
    local mt = getmetatable(luakit)
    assert.is_function(mt.__index, "luakit mt missing __index")
end

T.test_luakit_index = function ()
    local funcprops = { "exec", "quit", "save_file", "spawn", "spawn_sync",
        "time", "uri_decode", "uri_encode", "idle_add", "idle_remove" }
    for _, p in ipairs(funcprops) do
        assert.is_function(luakit[p], "Missing/invalid function: luakit."..p)
    end

    local strprops = { "cache_dir", "config_dir", "data_dir", "execpath",
        "confpath", "install_path", "version" }
    for _, p in ipairs(strprops) do
        assert.is_string(luakit[p], "Missing/invalid property: luakit."..p)
    end

    local boolprops = { "dev_paths", "verbose", "nounique" }
    for _, p in ipairs(boolprops) do
        assert.is_boolean(luakit[p], "Missing/invalid property: luakit."..p)
    end

    assert.is_number(luakit.time(), "Invalid: luakit.time()")
end

T.test_webkit_version = function ()
    assert.is_match("^%d+%.%d+%.%d+$", luakit.webkit_version,
        "Invalid format: luakit.webkit_version")
    assert.is_match("^%d+%.%d+$", luakit.webkit_user_agent_version,
        "Invalid format: luakit.webkit_user_agent_version")
end

T.test_windows_table = function ()
    assert.is_table(luakit.windows, "Missing/invalid luakit.windows table.")
    local baseline = #luakit.windows
    assert.is_number(baseline, "Invalid number of windows")
    local win = widget{type="window"}
    assert.is_equal(baseline+1, #luakit.windows,
        "luakit.windows not tracking opened windows.")
    win:destroy()
    assert.is_equal(baseline, #luakit.windows,
        "luakit.windows not tracking closed windows.")
end

T.test_invalid_prop = function ()
    assert.is_nil(luakit.invalid_property)
end

T.test_idle_add_del = function ()
    local f = function () end
    assert.is_false(luakit.idle_remove(f),
        "Function can't be removed before it's been added.")
    for _ = 1,5 do
        luakit.idle_add(f)
    end
    for _ = 1,5 do
        assert.is_true(luakit.idle_remove(f), "Error removing callback.")
    end
    assert.is_false(luakit.idle_remove(f),
        "idle_remove removed incorrect number of callbacks.")
end

T.test_register_scheme = function ()
    assert.has_error(function () luakit.register_scheme("") end)
    assert.has_error(function () luakit.register_scheme("http") end)
    assert.has_error(function () luakit.register_scheme("https") end)
    assert.has_error(function () luakit.register_scheme("ABC") end)
    assert.has_error(function () luakit.register_scheme(" ") end)
    luakit.register_scheme("test-scheme-name")
    luakit.register_scheme("a-.++...--8970d-d-")
end

T.test_website_data = function ()
    local _, minor = luakit.webkit_version:match("^(%d+)%.(%d+)%.")
    if tonumber(minor) < 16 then return end

    local wd = luakit.website_data
    assert.is_table(wd)
    assert.is_function(wd.fetch)
    assert.has_error(function () wd.fetch("") end)
    assert.has_error(function () wd.fetch({}) end)
    assert.has_error(function () wd.remove("") end)
    assert.has_error(function () wd.remove({}) end)
    assert.has_error(function () wd.remove({"all"}) end)

    local v = widget{type="webview"}

    coroutine.wrap(function ()
        assert(not wd.fetch({"all"})["Local files"])
        test.continue()
    end)()
    test.wait(1000)

    v.uri = "file:///"
    test.wait_for_view(v)

    coroutine.wrap(function ()
        assert(wd.fetch({"all"})["Local files"])
        wd.remove({"all"}, "Local files")
        assert(not wd.fetch({"all"})["Local files"])
        test.continue()
    end)()
    test.wait()

    v:destroy()
end

T.test_luakit_install_paths = function ()
    local paths = assert(luakit.install_paths)
    assert.equal(paths.install_dir, luakit.install_path)
    for _, k in ipairs {"install_dir", "config_dir", "doc_dir", "man_dir", "pixmap_dir", "app_dir"} do
        assert(type(paths[k]) == "string")
    end
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
