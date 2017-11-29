--- Basic async test functions.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local T = {}
local test = require "tests.lib"
local assert = require("luassert")
local spy = require 'luassert.spy'
local match = require("luassert.match")

uris = {"about:blank"}
require "config.rc"

local window = require "window"
local w = assert(select(2, next(window.bywidget)))

T.test_undo_close_works = function ()
    -- Load page in new tab
    local uri = test.http_server() .. "undoclose_page.html"
    w:new_tab(uri)
    assert(w.tabs:current() == 2)
    test.wait_for_view(w.view)

    -- Try to open the menu
    local notify_spy = spy.on(window.methods, "notify")
    w:run_cmd(":undolist")
    assert.spy(notify_spy).was.called_with(match._, "No closed tabs to display")
    assert(w:is_mode("normal"))

    -- Close the tab
    w:close_tab()
    assert(w.tabs:current() == 1)

    -- Try to open the menu again
    notify_spy = spy.on(window.methods, "notify")
    w:run_cmd(":undolist")
    assert.spy(notify_spy).was_not_called_with(match._, "No closed tabs to display")
    assert(w:is_mode("undolist"))
    w:set_mode("normal")

    -- Undo-close the tab
    w:undo_close_tab(1)
    assert(w.tabs:current() == 2)
    test.wait_for_view(w.view)

    assert(w.view.uri == uri)
    assert(w.view.title == "undoclose_page")

    -- Restore to initial state
    w:close_tab()
    assert(w.tabs:current() == 1)
    assert(w.view.uri == "about:blank")
end

T.test_undo_close_restores_tab_history = function ()
    -- Load page in new tab
    local uri = test.http_server() .. "undoclose_page.html"
    w:new_tab(uri)
    assert.is_equal(w.tabs:current(), 2)
    test.wait_for_view(w.view)

    -- Navigate to about:blank
    w.view.uri = "about:blank"
    test.wait_for_view(w.view)

    -- Close and undo-close
    w:close_tab()
    w:undo_close_tab()
    test.wait_for_view(w.view)
    assert.is_equal(w.tabs:current(), 2)
    assert.is_equal(w.view.uri, 'about:blank')

    -- Navigate back
    w:back(1)
    test.wait_for_view(w.view)
    assert.is_equal(w.view.uri, uri)

    -- Restore to initial state
    w:close_tab()
    assert(w.tabs:current() == 1)
    assert(w.view.uri == "about:blank")
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
