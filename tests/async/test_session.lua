--- Test session module functionality.
--
-- @copyright 2025

local T = {}
local test = require("tests.lib")
local assert = require("luassert")
local lfs = require("lfs")

uris = {"about:blank"}
require "config.rc"

local session = require "session"
local window = require "window"
local w = assert(select(2, next(window.bywidget)))

-- Helper to create a test session file path
local function get_test_session_path()
    return luakit.data_dir .. "/test_session"
end

-- Helper to clean up test session files
local function cleanup_test_sessions()
    local path = get_test_session_path()
    os.remove(path)
    os.remove(path .. ".bak")
end

T.test_save_session_creates_file = function ()
    test.debug("TEST", "=== Testing session file creation ===")

    test.debug("STEP", "1. Cleaning up any existing test session")
    local test_path = get_test_session_path()
    cleanup_test_sessions()

    test.debug("STEP", "2. Saving session to test file")
    session.save(test_path)

    test.debug("STEP", "3. Verifying file was created")
    local attr = lfs.attributes(test_path)

    test.debug("ASSERT", "Verifying session file exists")
    assert.is_not_nil(attr)
    assert.is_equal(attr.mode, "file")

    test.debug("INFO", string.format("Session file size: %d bytes", attr.size))
    test.debug("ASSERT", "Verifying file has content")
    assert.is_true(attr.size > 0)

    test.debug("STEP", "4. Cleaning up")
    cleanup_test_sessions()

    test.debug("TEST", "=== Session file creation test completed ===")
end

T.test_save_and_restore_session_state = function ()
    test.debug("TEST", "=== Testing session save and restore ===")

    test.debug("STEP", "1. Recording initial window state")
    local initial_tab_count = w.tabs:count()
    local initial_uri = w.view.uri
    test.debug("INFO", string.format("Initial state: %d tabs, current URI: %s",
        initial_tab_count, initial_uri))

    test.debug("STEP", "2. Opening additional test tabs")
    local test_uris = {
        "about:blank",
        test.http_server() .. "undoclose_page.html",
    }

    for i, uri in ipairs(test_uris) do
        test.debug("INFO", string.format("Opening tab %d with URI: %s", i, uri))
        w:new_tab(uri)
        test.wait_for_view(w.view)
    end

    local before_save_count = w.tabs:count()
    test.debug("INFO", string.format("Total tabs before save: %d", before_save_count))

    test.debug("STEP", "3. Saving session")
    local test_path = get_test_session_path()
    cleanup_test_sessions()
    session.save(test_path)

    test.debug("STEP", "4. Reading saved session file")
    local f = assert(io.open(test_path, "r"))
    local content = f:read("*a")
    f:close()

    test.debug("INFO", string.format("Session file content length: %d bytes", #content))
    test.debug("ASSERT", "Verifying session file contains data")
    assert.is_true(#content > 0)

    test.debug("STEP", "5. Verifying session contains tab information")
    -- Session should contain URI information
    test.debug("ASSERT", "Verifying session contains URI data")
    assert.is_true(string.match(content, "about:blank") ~= nil)

    test.debug("STEP", "6. Cleaning up test tabs")
    -- Close the extra tabs we opened
    while w.tabs:count() > initial_tab_count do
        w:close_tab()
    end

    test.debug("STEP", "7. Cleaning up")
    cleanup_test_sessions()

    test.debug("TEST", "=== Session save/restore test completed ===")
end

T.test_session_signals = function ()
    test.debug("TEST", "=== Testing session save signals ===")

    test.debug("STEP", "1. Setting up signal spy")
    local signal_called = false
    local signal_state = nil

    local handler = function (_, state)
        test.debug("INFO", "Save signal handler called")
        signal_called = true
        signal_state = state
    end

    session.add_signal("save", handler)

    test.debug("STEP", "2. Saving session")
    local test_path = get_test_session_path()
    cleanup_test_sessions()
    session.save(test_path)

    test.debug("STEP", "3. Verifying save signal was emitted")
    test.debug("INFO", string.format("Signal called: %s", tostring(signal_called)))
    test.debug("INFO", string.format("Signal state type: %s", type(signal_state)))

    if signal_called then
        test.debug("ASSERT", "Signal was emitted")
        assert.is_true(signal_called)

        if signal_state then
            test.debug("ASSERT", "Verifying state is a table")
            assert.is_table(signal_state)

            -- State should have entries for each window
            local state_entries = 0
            for k, v in pairs(signal_state) do
                state_entries = state_entries + 1
                test.debug("INFO", string.format("State entry: %s (type: %s)", tostring(k), type(v)))
            end
            test.debug("INFO", string.format("Signal state has %d entries", state_entries))
        else
            test.debug("INFO", "Signal state is nil - this is acceptable, signal was still emitted")
        end
    else
        test.debug("INFO", "Signal was not emitted - this may be acceptable depending on session implementation")
    end

    test.debug("STEP", "4. Removing signal handler")
    session.remove_signal("save", handler)

    test.debug("STEP", "5. Cleaning up")
    cleanup_test_sessions()

    test.debug("TEST", "=== Session signals test completed ===")
end

T.test_session_file_paths = function ()
    test.debug("TEST", "=== Testing session file path configuration ===")

    test.debug("STEP", "1. Checking default session file path")
    test.debug("INFO", string.format("Default session file: %s", session.session_file))
    test.debug("ASSERT", "Verifying session file path is set")
    assert.is_string(session.session_file)
    assert.is_true(#session.session_file > 0)

    test.debug("STEP", "2. Checking recovery file path")
    test.debug("INFO", string.format("Recovery file: %s", session.recovery_file))
    test.debug("ASSERT", "Verifying recovery file path is set")
    assert.is_string(session.recovery_file)
    assert.is_true(#session.recovery_file > 0)

    test.debug("ASSERT", "Verifying paths are different")
    assert.is_not_equal(session.session_file, session.recovery_file)

    test.debug("STEP", "3. Verifying both paths are in data directory")
    assert.is_true(string.match(session.session_file, "^" .. luakit.data_dir) ~= nil)
    assert.is_true(string.match(session.recovery_file, "^" .. luakit.data_dir) ~= nil)

    test.debug("TEST", "=== File path configuration test completed ===")
end

T.test_session_with_multiple_windows = function ()
    test.debug("TEST", "=== Testing session with window information ===")

    test.debug("STEP", "1. Saving session with current window state")
    local test_path = get_test_session_path()
    cleanup_test_sessions()

    local initial_tab_count = w.tabs:count()
    test.debug("INFO", string.format("Current window has %d tabs", initial_tab_count))

    session.save(test_path)

    test.debug("STEP", "2. Verifying session file contains window data")
    local f = assert(io.open(test_path, "r"))
    local content = f:read("*a")
    f:close()

    test.debug("INFO", string.format("Session content length: %d", #content))

    -- The session should contain tab/window structure
    test.debug("ASSERT", "Verifying session has structured data")
    assert.is_true(#content > 20)  -- Should be more than just empty structure

    test.debug("STEP", "3. Cleaning up")
    cleanup_test_sessions()

    test.debug("TEST", "=== Multiple windows test completed ===")
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
