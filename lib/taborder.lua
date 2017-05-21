--- Rules for where to put new tabs.
--
-- When a new tab is opened in a window, a tab order function is called to
-- determine where in the tab list it should be placed. window.new_tab()
-- accepts a tab order function as parameter. If this is not sent,
-- taborder.default is used if the new tab will be immediately switched to.
-- Otherwise, i.e. if a background tab is opened, taborder.bgdefault is used.
--
-- A tab order function receives the current window, and the view that is being
-- opened as parameters. In return, it gives the index at which the new tab
-- should be put.
--
-- @module taborder
-- @copyright 2010 Henrik Hallberg <henrik@k2h.se>

local lousy = require("lousy")

local _M = {}

--- Tab order function: Always insert new tabs before all other tabs.
_M.first = function()
    return 1
end

--- Tab order function: Always insert new tabs after all other tabs.
-- @tparam table w The current window table.
_M.last = function(w)
    return w.tabs:count() + 1
end

--- Tab order function: Always insert new tabs after the current tab.
-- @tparam table w The current window table.
_M.after_current = function (w)
    return w.tabs:current() + 1
end

--- Tab order function: Always insert new tabs before the current tab.
-- @tparam table w The current window table.
_M.before_current = function (w)
    return w.tabs:current()
end

--- Tab order function: Put new child tab next to the parent after unbroken chain of descendants.
-- Logical way to use when one "queues" background-followed links.
-- @tparam table w The current window table.
-- @tparam widget newview The new webview widget.
_M.by_origin = function(w, newview)
    local newindex = 0
    local currentview = w.view
    if not currentview then return 1 end

    local kids = _M.kidsof
    local views = w.tabs.children

    if kids[currentview] then
        -- Collect all descendants
        local desc = { currentview }
        local ii = 1
        repeat
            desc = lousy.util.table.join(desc, kids[desc[ii]])
            ii = ii + 1
        until ii > #desc

        -- Find the non-descendant closest after current. This is where
        -- the new tab should be put.
        for i = #views, 1, -1 do
            if not lousy.util.table.hasitem(desc, views[i]) then
                newindex = i
            end
            if views[i] == currentview then
                break
            end
        end

        -- There were no non-descendants after current. Put new tab last.
        if newindex == 0 then newindex = _M.last(w, newview) end
    else
        kids[currentview] = {}
        newindex = _M.after_current(w, newview)
    end

    table.insert(kids[currentview], newview)

    return newindex
end

--- Default tab order function: open regular tabs last.
-- @readwrite
_M.default = _M.last

--- Default tab order function for background tabs: open by origin.
-- @readwrite
_M.default_bg = _M.by_origin

--- Weak table to remember which tab was spawned from which parent.
-- Note that family bonds are tied only if tabs are spawned within
-- family rules, e.g. from by_origin. Tabs created elsewhere are orphans.
-- @readwrite
_M.kidsof = {}
setmetatable(_M.kidsof, { __mode = "k" })

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
