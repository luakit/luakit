--- Test session module.
--
-- @copyright 2026

local assert = require "luassert"
local test = require "tests.lib"

uris = {"about:blank"}
require "config.rc"

local window = require "window"
local w = assert(select(2, next(window.bywidget)))
local session = require "session"

local T = {}

T.test_session_save_and_load = function ()
    test.wait_for_idle()

    local temp_file = luakit.data_dir .. "/session_test"
    os.remove(temp_file)

    -- Make sure we have a known state: two tabs
    local initial_tab_count = #w.tabs
    local target_uri = test.http_server() .. "test_follow.html"
    w:new_tab(target_uri)
    test.wait_for_view(w.view)

    assert.equal(initial_tab_count + 1, #w.tabs)

    -- Save session
    session.save(temp_file)
    test.wait_for_idle()

    -- Check if session file was created
    local f = io.open(temp_file, "r")
    assert.is_not_nil(f, "Session file not created")
    f:close()

    -- Load session and check contents
    local state = session.load(false, temp_file)
    assert.is_table(state)
    assert.is_true(#state >= 1)

    local win_state = state[1]
    assert.is_table(win_state)
    assert.is_table(win_state.open)
    assert.equal(#w.tabs, #win_state.open)

    -- Verify URI of second tab in saved state
    local found_uri = false
    for _, tab_state in ipairs(win_state.open) do
        if tab_state.uri == target_uri then
            found_uri = true
        end
    end
    assert.is_true(found_uri, "Target tab URI not found in saved session state")

    -- Clean up
    w:close_tab()
    os.remove(temp_file)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
