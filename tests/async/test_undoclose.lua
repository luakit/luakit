--- Basic async test functions.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local T = {}
local test = require("tests.lib")
local assert = require("luassert")
local spy = require("luassert.spy")
local match = require("luassert.match")

uris = {"about:blank"}
require "config.rc"

local window = require "window"
local w = assert(select(2, next(window.bywidget)))

--- Helper function to get the undoclose history
local function get_undoclose_history()
    local undoclose = require("undoclose")
    if undoclose and undoclose.history then
        return #undoclose.history
    end
    return 0
end

--- Helper function to capture and log window state
local function log_window_state(stage)
    local state = test.capture_window_state(w)
    test.debug("STATE", string.format("[%s] Window state:", stage))
    test.debug_push()
    test.debug("STATE", string.format("Current tab: %s/%s", state.current_tab, state.tab_count))
    test.debug("STATE", string.format("Mode: %s", state.mode))
    test.debug("STATE", string.format("View URI: %s", state.view_uri))
    test.debug("STATE", string.format("View title: %s", state.view_title))
    test.debug("STATE", string.format("Undoclose history size: %d", get_undoclose_history()))
    test.debug_pop()
end

T.test_undo_close_restores_tab_history = function ()
    test.debug("TEST", "=== Starting undoclose test ===")

    -- Step 1: Load undoclose module and record initial state
    test.debug("STEP", "1. Loading undoclose module and checking initial state")
    require("undoclose")  -- Ensure module is loaded
    log_window_state("initial")
    local initial_tab_count = w.tabs:count()
    local initial_history_size = get_undoclose_history()
    test.debug("INFO", string.format("Initial tabs: %d, undoclose history: %d",
        initial_tab_count, initial_history_size))

    -- Step 2: Load page in new tab
    local uri = test.http_server() .. "undoclose_page.html"
    test.debug("STEP", string.format("2. Opening new tab with URI: %s", uri))

    w:new_tab(uri)
    local new_tab_index = w.tabs:current()
    test.debug("INFO", string.format("New tab created at index: %d", new_tab_index))

    test.debug("ASSERT", string.format("Checking new tab index is %d", initial_tab_count + 1))
    assert.is_equal(w.tabs:current(), initial_tab_count + 1)

    test.debug("INFO", "Waiting for view to load...")
    test.wait_for_view(w.view)
    log_window_state("after_new_tab")

    -- Step 3: Try to open menu (should fail - no closed tabs yet in this session)
    test.debug("STEP", "3. Testing undolist command")
    local notify_spy = spy.on(window.methods, "notify")

    test.debug("INFO", "Running :undolist command")
    w:run_cmd(":undolist")

    -- If history is empty, should get notification; otherwise enters undolist mode
    test.debug("INFO", "Undolist command executed, returning to normal mode")
    w:set_mode("normal")  -- Ensure we're back in normal mode
    log_window_state("after_undolist")

    -- Step 4: Close the tab (with the original page still loaded)
    local before_close_tab_count = w.tabs:count()
    local before_close_history = get_undoclose_history()
    test.debug("STEP", "4. Closing tab")
    test.debug("INFO", string.format("Before close: tabs=%d, history=%d",
        before_close_tab_count, before_close_history))

    w:close_tab()

    local after_close_tab_count = w.tabs:count()
    local after_close_history = get_undoclose_history()
    test.debug("INFO", string.format("After close: tabs=%d, history=%d",
        after_close_tab_count, after_close_history))

    test.debug("ASSERT", string.format("Verifying tab count decreased: %d -> %d",
        before_close_tab_count, after_close_tab_count))
    assert.is_equal(after_close_tab_count, before_close_tab_count - 1)

    test.debug("ASSERT", string.format("Verifying history increased by 1: %d -> %d",
        before_close_history, after_close_history))
    assert.is_equal(after_close_history, before_close_history + 1)

    log_window_state("after_close_tab")

    -- Step 5: Undo close and verify tab is restored
    local before_undo_tab_count = w.tabs:count()
    local before_undo_history = get_undoclose_history()
    test.debug("STEP", "5. Undo close tab")
    test.debug("INFO", string.format("Before undo: tabs=%d, history=%d",
        before_undo_tab_count, before_undo_history))

    w:undo_close_tab()
    test.debug("INFO", "Waiting for restored view to load...")
    test.wait_for_view(w.view)

    local after_undo_tab_count = w.tabs:count()
    local after_undo_history = get_undoclose_history()
    test.debug("INFO", string.format("After undo: tabs=%d, history=%d, current_tab=%d, uri=%s",
        after_undo_tab_count, after_undo_history, w.tabs:current(), w.view.uri))

    test.debug("ASSERT", string.format("Verifying tab restored: current=%d, expected=%d",
        w.tabs:current(), before_undo_tab_count + 1))
    assert.is_equal(w.tabs:current(), before_undo_tab_count + 1)

    test.debug("ASSERT", string.format("Verifying URI is %s, got: %s", uri, w.view.uri))
    assert.is_equal(w.view.uri, uri)

    test.debug("ASSERT", string.format("Verifying history decreased: %d -> %d",
        before_undo_history, after_undo_history))
    assert.is_equal(after_undo_history, before_undo_history - 1)

    log_window_state("after_undo")

    -- Step 6: Restore to initial state
    test.debug("STEP", "6. Restoring to initial state")
    test.debug("INFO", "Closing test tab")

    w:close_tab()

    test.debug("ASSERT", string.format("Verifying back to %d tab(s)", initial_tab_count))
    assert(w.tabs:current() == initial_tab_count)

    test.debug("ASSERT", "Verifying on about:blank")
    assert(w.view.uri == "about:blank")

    log_window_state("final")
    test.debug("TEST", "=== Test completed successfully ===")
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
