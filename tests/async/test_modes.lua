--- Test mode system functionality.
--
-- @copyright 2025

local T = {}
local test = require("tests.lib")
local assert = require("luassert")

uris = {"about:blank"}
require "config.rc"

local window = require "window"
local modes = require "modes"
local w = assert(select(2, next(window.bywidget)))

T.test_mode_creation_and_retrieval = function ()
    test.debug("TEST", "=== Testing mode creation and retrieval ===")

    test.debug("STEP", "1. Creating a custom test mode")
    modes.new_mode("test_mode", "Test mode description", {
        enter = function (win)
            win.test_mode_entered = true
        end,
        leave = function (win)
            win.test_mode_left = true
        end
    })

    test.debug("ASSERT", "Verifying mode was created")
    local mode = modes.get_mode("test_mode")
    assert.is_not_nil(mode)
    assert.is_equal(mode.name, "test_mode")
    assert.is_equal(mode.desc, "Test mode description")
    assert.is_function(mode.enter)
    assert.is_function(mode.leave)

    test.debug("TEST", "=== Mode creation test completed ===")
end

T.test_mode_switching = function ()
    test.debug("TEST", "=== Testing mode switching ===")

    test.debug("STEP", "1. Verifying initial mode is normal")
    test.debug("ASSERT", "Checking if in normal mode")
    assert.is_true(w:is_mode("normal"))

    test.debug("STEP", "2. Switching to insert mode")
    w:set_mode("insert")
    test.debug("ASSERT", "Verifying mode changed to insert")
    assert.is_true(w:is_mode("insert"))
    assert.is_false(w:is_mode("normal"))

    test.debug("STEP", "3. Switching back to normal mode")
    w:set_mode("normal")
    test.debug("ASSERT", "Verifying mode changed to normal")
    assert.is_true(w:is_mode("normal"))
    assert.is_false(w:is_mode("insert"))

    test.debug("TEST", "=== Mode switching test completed ===")
end

T.test_mode_hooks_are_called = function ()
    test.debug("TEST", "=== Testing mode enter/leave hooks ===")

    test.debug("STEP", "1. Clearing hook flags")
    w.test_mode_entered = nil
    w.test_mode_left = nil

    test.debug("STEP", "2. Entering test mode")
    w:set_mode("test_mode")

    test.debug("ASSERT", "Verifying enter hook was called")
    assert.is_true(w.test_mode_entered)
    assert.is_nil(w.test_mode_left)

    test.debug("STEP", "3. Leaving test mode")
    w:set_mode("normal")

    test.debug("ASSERT", "Verifying leave hook was called")
    assert.is_true(w.test_mode_left)

    test.debug("TEST", "=== Mode hooks test completed ===")
end

T.test_get_all_modes = function ()
    test.debug("TEST", "=== Testing get_modes ===")

    test.debug("STEP", "1. Getting all modes")
    local all_modes = modes.get_modes()

    test.debug("ASSERT", "Verifying modes table is returned")
    assert.is_table(all_modes)

    test.debug("STEP", "2. Checking for standard modes")
    local expected_modes = {"normal", "insert", "command", "passthrough"}

    for _, mode_name in ipairs(expected_modes) do
        test.debug("ASSERT", string.format("Verifying %s mode exists", mode_name))
        assert.is_not_nil(all_modes[mode_name])
        assert.is_equal(all_modes[mode_name].name, mode_name)
    end

    test.debug("STEP", "3. Verifying our test mode is in the list")
    assert.is_not_nil(all_modes["test_mode"])

    test.debug("TEST", "=== Get modes test completed ===")
end

T.test_mode_with_arguments = function ()
    test.debug("TEST", "=== Testing mode with arguments ===")

    test.debug("STEP", "1. Creating mode that accepts arguments")
    modes.new_mode("arg_test_mode", {
        enter = function (win, arg1, arg2)
            win.mode_arg1 = arg1
            win.mode_arg2 = arg2
        end
    })

    test.debug("STEP", "2. Entering mode with arguments")
    w:set_mode("arg_test_mode", "test_arg_1", "test_arg_2")

    test.debug("ASSERT", "Verifying arguments were passed")
    assert.is_equal(w.mode_arg1, "test_arg_1")
    assert.is_equal(w.mode_arg2, "test_arg_2")

    test.debug("STEP", "3. Returning to normal mode")
    w:set_mode("normal")

    test.debug("TEST", "=== Mode arguments test completed ===")
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
