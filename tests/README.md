# Luakit Test Suite

This directory contains the test suite for luakit, including both style/static analysis tests and async/integration tests.

## Running Tests

### Basic Usage

```bash
# Run all tests
make run-tests

# Run specific test(s)
make run-tests ARGS="undoclose"
make run-tests ARGS="test_settings test_scroll"
```

### Debug Mode

To enable rich debug output that shows detailed state information during test execution:

```bash
# Enable debug output for all tests
LUAKIT_TEST_DEBUG=1 make run-tests

# Enable debug output for specific test
LUAKIT_TEST_DEBUG=1 make run-tests ARGS="undoclose"
```

## Debug Output Features

When `LUAKIT_TEST_DEBUG=1` is set, tests will output:

### Categories of Debug Messages

- **[TEST]** - Test lifecycle events (start/end)
- **[STEP]** - Major test steps and phases
- **[STATE]** - Window and view state snapshots
- **[ASSERT]** - Assertion checks and their values
- **[INFO]** - General information about test actions
- **[WAIT]** - Waiting for signals or conditions
- **[SIGNAL]** - Signal emissions and receptions
- **[ERROR]** - Error conditions
- **[TIMING]** - Performance and timing information

### Example Debug Output

```
__debug__ [14:23:45] [TEST] === Starting undoclose test ===
__debug__ [14:23:45] [STEP] 1. Checking initial state
__debug__ [14:23:45] [STATE] [initial] Window state:
__debug__ [14:23:45] [STATE]   Current tab: 1/1
__debug__ [14:23:45] [STATE]   Mode: normal
__debug__ [14:23:45] [STATE]   View URI: about:blank
__debug__ [14:23:45] [STATE]   Undoclose history size: 0
__debug__ [14:23:45] [INFO] Initial tabs: 1, undoclose history: 0
__debug__ [14:23:45] [STEP] 2. Opening new tab with URI: luakit-test://undoclose_page.html
__debug__ [14:23:45] [INFO] New tab created at index: 2
__debug__ [14:23:45] [ASSERT] Checking new tab index is 2
```

## Test Structure

### Directory Layout

```
tests/
├── async/              # Async/integration tests (run in luakit instances)
│   ├── run_test.lua    # Async test runner
│   ├── test_*.lua      # Individual async tests
│   └── wrangle_paths.lua
├── style/              # Static analysis and code quality tests
│   ├── test_luacheck.lua
│   ├── test_source_format.lua
│   └── ...
├── html/               # HTML fixtures for tests
├── lib.lua             # Test library with helper functions
├── run_test.lua        # Main test runner
└── README.md           # This file
```

### Test Types

#### Async Tests (`tests/async/`)

These tests run in actual luakit instances with full browser functionality:

- **test_undoclose.lua** - Tab restoration functionality (ENHANCED with debug output)
- **test_binds_api.lua** - Keybinding API
- **test_clib_*.lua** - C library bindings
- **test_settings.lua** - Settings system
- **test_scroll.lua** - Scrolling behavior
- And more...

#### Style Tests (`tests/style/`)

These are static analysis tests that run without starting luakit:

- **test_luacheck.lua** - Lua static analysis with luacheck
- **test_source_format.lua** - Source code formatting checks
- **test_documentation.lua** - Documentation completeness

## Writing Tests

### Using Debug Output in Your Tests

```lua
local test = require("tests.lib")

T.test_my_feature = function()
    -- Log test start
    test.debug("TEST", "=== Testing my feature ===")

    -- Log test steps
    test.debug("STEP", "1. Setting up initial state")

    -- Log state information
    test.debug("STATE", "Current URI:", w.view.uri)

    -- Log assertions
    test.debug("ASSERT", "Checking tab count is 2")
    assert.is_equal(w.tabs:count(), 2)

    -- Use indentation for nested operations
    test.debug("INFO", "Starting nested operation")
    test.debug_push()
    test.debug("INFO", "Nested action 1")
    test.debug("INFO", "Nested action 2")
    test.debug_pop()

    -- Capture and log window state
    local state = test.capture_window_state(w)
    test.debug("STATE", "Window state:", test.table_to_string(state))

    test.debug("TEST", "=== Test completed ===")
end
```

### Helper Functions

#### `test.debug(category, ...)`
Output debug information (only when LUAKIT_TEST_DEBUG=1)

#### `test.debug_push()` / `test.debug_pop()`
Increase/decrease indentation level for nested operations

#### `test.capture_window_state(w)`
Capture current window state (tabs, mode, view info)

#### `test.capture_view_state(view)`
Capture current webview state (URI, title, loading status)

#### `test.table_to_string(table)`
Convert a table to a readable string representation

#### `test.wait_for_view(view)`
Wait for a webview to finish loading (enhanced with debug output)

## Troubleshooting Tests

### Common Issues

**Test fails sporadically:**
1. Enable debug mode to see state at each step: `LUAKIT_TEST_DEBUG=1 make run-tests`
2. Check for race conditions between tests
3. Verify proper cleanup in test teardown

**Test times out:**
1. Debug output shows which signal is being waited for
2. Default timeout is 200ms for most operations
3. Increase timeout for slow operations: `test.wait_for_signal(obj, sig, 5000)`

**State pollution between tests:**
1. Each async test runs in a fresh luakit instance
2. Each instance gets a temporary isolated directory
3. Style tests run in the same process but should not maintain state

### Debug Output Analysis

When a test fails with debug output enabled, look for:

1. **Last STATE message** - Shows the state when failure occurred
2. **Last ASSERT message** - Shows what was being checked
3. **WAIT/SIGNAL messages** - Shows if test is stuck waiting
4. **Undoclose history size** - Shows if history is properly managed

### Example: Analyzing an Undoclose Failure

If the undoclose test fails, the debug output will show:

```
__debug__ [14:23:45] [STEP] 7. First undo close (no argument)
__debug__ [14:23:45] [INFO] Before undo: tabs=1, history=1
__debug__ [14:23:45] [INFO] Waiting for restored view to load...
__debug__ [14:23:45] [WAIT] Waiting for view to finish loading: about:blank
__debug__ [14:23:46] [INFO] After undo: tabs=2, history=0, current_tab=2, uri=about:blank
__fail__ test_undo_close_restores_tab_history
Expected: 2
Actual: 1
```

This clearly shows:
- Before undo: 1 tab, 1 history entry ✓
- After undo: 2 tabs created, history consumed ✓
- **Problem**: Expected current_tab=2 but got 1

## Test Coverage

### Currently Covered

- ✓ Async operations and coroutines
- ✓ Keybinding API
- ✓ C library bindings (luakit, regex, soup, sqlite3, utf8)
- ✓ Command completion
- ✓ Configuration loading
- ✓ Gopher protocol
- ✓ Lousy utility library
- ✓ Memory leak detection
- ✓ Settings system
- ✓ Scrolling
- ✓ Tab restoration (undoclose)
- ✓ Widget API
- ✓ Source formatting
- ✓ Static analysis (luacheck)

### Areas Needing More Coverage

(To be expanded based on code audit)

## Dependencies

### Build Dependencies
- luajit (or lua 5.1)
- libluajit-5.1-dev
- libwebkit2gtk-4.1-dev
- libgtk-3-dev
- libglib2.0-dev

### Test Dependencies
- lua-check (luacheck)
- lua-luassert
- lua-filesystem (lfs)
- lua-socket
- Xvfb (for headless testing)

## CI/CD Integration

Tests run automatically on GitHub Actions for all pull requests.

See `.github/workflows/tests.yml` for CI configuration.
