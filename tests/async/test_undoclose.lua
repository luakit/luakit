--- Basic async test functions.
--
-- @copyright 2017 Aidan Holm

local T = {}
local test = require "tests.lib"
local assert = require("luassert")
local spy = require 'luassert.spy'
local match = require("luassert.match")

T.test_undo_close_works = function ()
    uris = {"about:blank"}
    require "config.rc"
    local window = require "window"
    local w = assert(select(2, next(window.bywidget)))

    -- Load page in new tab
    local uri = test.http_server() .. "undoclose_page.html"
    w:new_tab(uri)
    assert(w.tabs:current() == 2)
    repeat
        local _, status = test.wait_for_signal(w.view, "load-status", 1)
        assert(status ~= "failed")
    until status == "finished"

    -- Try to open the menu
    assert(#w.closed_tabs == 0 or w.closed_tabs == nil)
    local notify_spy = spy.on(window.methods, "notify")
    w:run_cmd(":undolist")
    assert.spy(notify_spy).was.called_with(match._, "No closed tabs to display")
    assert(w:is_mode("normal"))

    -- Close the tab
    w:close_tab()
    assert(w.tabs:current() == 1)
    assert(#w.closed_tabs == 1)
    local tab = w.closed_tabs[1]
    assert(tab.uri == uri)
    assert(tab.title == "undoclose_page")

    -- Try to open the menu again
    notify_spy = spy.on(window.methods, "notify")
    w:run_cmd(":undolist")
    assert.spy(notify_spy).was_not_called_with(match._, "No closed tabs to display")
    assert(w:is_mode("undolist"))
    assert(w.menu:nrows() == #w.closed_tabs + 1) -- +1 for heaeding
    w:set_mode("normal")

    -- Undo-close the tab
    w:undo_close_tab(1)
    assert(w.tabs:current() == 2)
    repeat
        local _, status = test.wait_for_signal(w.view, "load-status", 1)
        assert(status ~= "failed")
    until status == "finished"

    assert(#w.closed_tabs == 0)
    assert(w.view.uri == uri)
    assert(w.view.title == "undoclose_page")
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
