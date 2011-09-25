--------------------------------------------
-- Rules for where to put new tabs        --
-- © 2010 Henrik Hallberg <henrik@k2h.se> --
--------------------------------------------

-- When a new tab is opened in a window, a tab order function is called to
-- determine where in the tab list it should be placed. window.new_tab()
-- accepts a tab order function as parameter. If this is not sent,
-- taborder.default is used if the new tab will be immediately switched to.
-- Otherwise, i.e. if a background tab is opened, taborder.bgdefault is used.
--
-- A tab order function receives the current window, and the view that is being
-- opened as parameters. In return, it gives the index at which the new tab
-- should be put.

taborder = {
    first = function()
        return 1
    end,

    last = function(w)
        return w.tabs:count() + 1
    end,

    after_current = function (w)
        return w.tabs:current() + 1
    end,

    before_current = function (w)
        return w.tabs:current()
    end,

    -- Put new child tab next to the parent after unbroken chain of descendants
    -- Logical way to use when one "queues" background-followed links
    by_origin = function(w, newview)
        local newindex = 0
        local currentview = w.view
        if not currentview then return 1 end

        local kids = taborder.kidsof
        local views = w.tabs.children

        if kids[currentview] then
            -- Collect all descendants
            local desc = { currentview }
            local i = 1
            repeat
                desc = lousy.util.table.join(desc, kids[desc[i]])
                i = i + 1
            until i > #desc

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
            if newindex == 0 then newindex = taborder.last(w, newview) end
        else
            kids[currentview] = {}
            newindex = taborder.after_current(w, newview)
        end

        table.insert(kids[currentview], newview)

        return newindex
    end,
}

-- Default: open regular tabs last
taborder.default = taborder.last
-- Default: open background tabs by origin
taborder.default_bg = taborder.by_origin

-- Weak table to remember which tab was spawned from which parent
-- Note that family bonds are tied only if tabs are spawned within
-- family rules, e.g. from by_origin. Tabs created elsewhere are orphans.
taborder.kidsof = {}
setmetatable(taborder.kidsof, { __mode = "k" })

-- vim: et:sw=4:ts=8:sts=4:tw=80
