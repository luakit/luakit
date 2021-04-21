--- Tab groups management module.
--
-- This module allows you to group opened tabs and switch between different groups
-- and tabs in groups
--
-- # Capabilities
--
-- # Usage
--
-- * Add `require "tabgroups"` to your `rc.lua`.
-- * Press 'x' to open list of defined tabgroups.
-- * Press 'X' to open list of tabs in active tabgroup.
-- * (Optional) add the `tgname` widget to your status bar.
--
-- # Troubleshooting
--
-- # Files and Directories
--
--
-- @module tabgroups
-- @author Serg Kozhemyakin <serg.kozhemyakin@gmail.com>
-- @author Aidan Holm <aidanholm@gmail.com>
-- @copyright 2017 Serg Kozhemyakin <serg.kozhemyakin@gmail.com>

local window = require("window")
local webview = require("webview")
local binds, modes = require("binds"), require("modes")
local add_binds = modes.add_binds
local menu_binds = binds.menu_binds
local new_mode = require("modes").new_mode
local session = require("session")
local settings = require("settings")
local lousy = require("lousy")

local _M = {}

local _new_tabgroup_prefix = "Unnamed#"
local _default_notify = "n: create new group, d: delete group, r: rename group"

-- private hash for storing map uri to tabgroup
local w2groups = setmetatable({}, { __mode = "k" })

-- temporary table for storing deleted notebooks, will be cleaned at idle time
local _deleted_groups = {}

local switch_tabgroup, delete_tabgroup

local function _get_next_tabgroup_name(w)
    local name
    local i = 1
    if w2groups[w] and w2groups[w].groups then
        repeat
            i = i + 1
            name = _new_tabgroup_prefix .. i
        until not w2groups[w].groups[name]
    else
        name = _new_tabgroup_prefix .. i
    end
    return name
end

local function grouptabs(w, g)
    assert(type(g) == 'string')
    local group = assert(w2groups[w].groups[g])
    assert(group._notebook)
    assert(group._notebook.type == "notebook")
    local i = 0
    local n = group._notebook:count()
    return function()
        i = i + 1
        if i <= n then return i, group._notebook[i] end
    end
end

local function webview2idx(view)
    local nb = assert(view.parent)
    -- should we have separate handling for case when
    -- view.parent is not same as w2groups[w].groups[group]._notebook?
    -- this case means that we messed with webviews somehow and attached it
    -- to different notebook manually. hope we don't need to workaroudn
    -- such setups.
    return nb:indexof(view)
end

-- return table with tabgroup info
local function webview2group(view)
    local nb = assert(view.parent)
    local w = assert(window.ancestor(nb))
    for _, gv in pairs(w2groups[w].groups) do
        if gv._notebook == nb then
            return gv
        end
    end
    return nil
end

-- return table with tabgroup info
local function tablist2group(nb)
    -- don't use assert here because this sub may be called
    -- on deleted tabgroup that already detauched from window
    -- no need to spam log with useless assert messages
    local w = window.ancestor(nb)
    if w then
        for _, gv in pairs(w2groups[w].groups) do
            if gv._notebook == nb then
                return gv
            end
        end
    end
    return nil
end

local function current_webview_in_group(w, group)
    local ret = nil
    if w2groups[w] and w2groups[w].groups[group] then
        local g = w2groups[w].groups[group]
        ret = g._notebook[g._notebook:current()]
    end
    return ret
end

local function number_of_tabgroups(w)
    local n = 0
    for _, _ in pairs(w2groups[w].groups) do
        n = n + 1
    end
    return n
end

local function _page_added_cb(nb, view)
    local g = assert(tablist2group(nb))
    assert(not g.tabs[view])
    g.tabs[view] = { tab_hit = 0, atime = 0, ctime = os.time(), mtime = 0, }
    g.mtime = os.time();
    view:add_signal("property::uri", function (v)
        local grp = webview2group(v)
        assert(grp)
        grp.tabs[v].mtime = os.time()
    end)
end

local function _page_removed_cb(nb, view)
    local g = tablist2group(nb)
    if g then
        if g.tabs[view] then
            g.tabs[view] = nil
        end
        g.mtime = os.time();
    end
end

local function _switch_page_cb(nb, view)
    local g = assert(tablist2group(nb))
    local tab = assert(g.tabs[view])
    tab.tab_hit = tab.tab_hit + 1
    tab.atime = os.time()
end

local function add_signals_to_notebook(nb)
    nb:add_signal("page-added", _page_added_cb)
    nb:add_signal("page-removed", _page_removed_cb)
    nb:add_signal("switch-page", _switch_page_cb)
end

-- return tabgroup table, newly created or already existing
local function create_tabgroup(w, group_name)
    if not w2groups[w].groups[group_name] then
        local nt = widget({type="notebook"})
        w.tabs.parent:insert(nt)
        nt.show_tabs = false

        w2groups[w].groups[group_name] = {
            name = group_name,
            _notebook = nt,
            group_hit = 0,
            atime = 0,
            mtime = 0,
            ctime = os.time(),
            tabs = {},
        }

        add_signals_to_notebook(nt)
    end
    return w2groups[w].groups[group_name]
end

local function _select_next_opened_tabgroup(w, group)
    local switch_to = nil
    local tg_list, n, idx = {}, 1, -1
    for name, _ in pairs(w2groups[w].groups) do
        tg_list[n] = name
        if name == group then idx = n end
        n = n + 1
    end
    if idx > 0 then
        switch_to = tg_list[idx + (idx == 1 and 1 or -1)]
    end
    return switch_to
end

local function open_new_tab_in_tabgroup (w, group, uri, opts)
    local tg = create_tabgroup(w, group)
    opts = opts or {}
    if tg then
        local view = webview.new({ private = opts.private })
        if opts.session_restore then
            webview.modify_load_block(view, "tabgroups-restore", true)
            local function unblock(vv)
                webview.modify_load_block(vv, "tabgroups-restore", false)
                vv:remove_signal("switched-page", unblock)
            end
            view:add_signal("switched-page", unblock)
        end
        -- copy/pasted from attach_tab function in window module
        local order = opts.order
        local taborder = package.loaded.taborder
        if not order and taborder then
            order = (opts.switch == false and taborder.default_bg)
                or taborder.default
        end
        local pos = tg._notebook:insert((order and order(w, view)) or -1, view)
        assert(tg.tabs[view])
        assert(tg._notebook)
        webview.set_location(view, { session_state = opts.session_state, uri = uri or opts.uri, })
        if opts.switch then
            tg._notebook:switch(pos)
        end
    end
end

local function _cleaner()
    for k, g in pairs(_deleted_groups) do
        if g and g._notebook then
            g._notebook:remove_signal("page-removed", _page_removed_cb)
            g._notebook:remove_signal("page-added", _page_added_cb)
            g._notebook:remove_signal("switch-page", _switch_page_cb)
            for i = 1, g._notebook:count() do
                local v = g._notebook[i]
                if v then
                    g._notebook:remove(v)
                end
            end
            g._notebook = nil
        end
        _deleted_groups[k] = nil
    end
    return false
end

window.add_signal("init", function (w)
    local group_name = _get_next_tabgroup_name(w)
    w2groups[w] = { active = group_name , groups = {},  }

    local _nb = w.tabs
    local group_nb = widget{type="notebook"}
    group_nb.show_tabs = false
    _nb:replace(group_nb)
    group_nb:insert(_nb)

    w2groups[w].groups[group_name] = {
        name = group_name,
        _notebook = w.tabs,
        group_hit = 0,
        atime = os.time(),
        mtime = os.time(),
        ctime = os.time(),
        tabs = {},
    }

    add_signals_to_notebook(w.tabs)

    w:add_signal("detach-tab", function (win, _)
        local current_tg_name = w2groups[win].active
        local nb = w2groups[win].groups[current_tg_name]._notebook
        if nb:count() == 1 then
            -- if we closing last tab in active tabgroup -- let's switch to other tabgroup
            -- and remove current one
            if number_of_tabgroups(win) > 1 then
                switch_tabgroup(win, _select_next_opened_tabgroup(w, current_tg_name))
            end
            delete_tabgroup(win, current_tg_name)
        end
    end)
end)

-- add to popup menu submenu for opening new tab in different tabgroups
local function populate_open_in_tabgroup_menu (view, menu)
    -- populate this menu only if we hovering some uri
    local uri = view.hovered_uri
    if uri then
        local w = window.ancestor(view)
        local tabgroups = {}
        for g, _ in pairs(w2groups[w].groups) do
            -- skip active tabgroup
            if g ~= w2groups[w].active then
                table.insert(tabgroups, g)
            end
        end

        -- if we have more then one tabgroup then let's populate submenu
        if #tabgroups > 0 then
            local switch_to = settings.get_setting("tabgroups.switch_to_new_tab")
            local submenu = {}
            local n = 1
            for _, tg in ipairs(tabgroups) do
                submenu[n] = { tg, function (_)
                    open_new_tab_in_tabgroup(w, tg, uri, {switch = switch_to })
                    if switch_to then
                        switch_tabgroup(w, tg)
                    end
                end}
                n = n+1
            end

            -- look for menu item "Open Link in New Tab"
            for i, mi in ipairs(menu) do
                if type(mi) == 'table' and mi[1] == 'Open Link in New Tab' then
                    n = i
                    break
                end
            end

            -- add submenu after 'Open Link in New Tab'
            table.insert(menu, n+1, { "Open Link in Tab Group", submenu })
        end
    end
end

webview.add_signal("init", function (view)
    view:add_signal("populate-popup", populate_open_in_tabgroup_menu)
end)

-- session handling
session.add_signal("restore", function (state)
    for w, win_state in pairs(state) do
        if win_state.tab_groups then
            -- let's rename default group as active one, if name is different
            if win_state.tab_groups.active ~= w2groups[w].active then
                local groups = w2groups[w].groups
                groups[win_state.tab_groups.active] = groups[w2groups[w].active]
                groups[w2groups[w].active] = nil
                w2groups[w].active = win_state.tab_groups.active
                groups[win_state.tab_groups.active].name = win_state.tab_groups.active
            end

            for gn, g in pairs(win_state.tab_groups.groups) do
                local src = win_state.tab_groups.groups[gn]
                for i, stat in ipairs(g.tabs) do
                    if gn ~= w2groups[w].active then
                        open_new_tab_in_tabgroup(w, gn, stat.uri,  {
                            switch = g.active == i,
                            session_state = stat.session_state,
                            session_restore = true,
                        })
                    end
                    local group = w2groups[w].groups[gn]
                    group.tabs[i]  = {
                        tab_hit = stat.tab_hit,
                        atime = stat.atime,
                        ctime = stat.ctime,
                        mtime = stat.mtime,
                    }
                end
                local group = w2groups[w].groups[gn]
                if group then
                    group.name = src.name
                    group.atime = src.atime or 0
                    group.mtime = src.mtime or 0
                    group.ctime = src.ctime or os.time()
                else
                    create_tabgroup(w, gn)
                end
            end
        end
    end
end)

session.add_signal("save", function(state)
    local wins = lousy.util.table.values(window.bywidget)
    for _, w in ipairs(wins) do
        state[w].tab_groups = { active = w2groups[w].active, groups = {}, }
        for gn, g in pairs(w2groups[w].groups) do
            local _a = current_webview_in_group(w, gn)
            state[w].tab_groups.groups[gn] = {
                name = gn,
                group_hit = g.group_hit,
                atime = g.atime,
                ctime = g.ctime,
                mtime = g.mtime,
                tabs = {},
            }
            local dst = state[w].tab_groups.groups[gn]
            for i, v in grouptabs(w, gn) do
                local tab = assert(g.tabs[v])
                local tab_info = {
                    tab_hit = tab.tab_hit or 0,
                    atime = tab.atime,
                    mtime = tab.mtime,
                    ctime = tab.ctime,
                }
                -- we don't store uri and state for tabs in active tg because this info already stored
                -- by luakit session manager
                if gn ~= w2groups[w].active then
                    tab_info.uri = v.uri
                    tab_info.session_state = v.session_state
                end
                dst.tabs[i] = tab_info
                if v == _a then
                    dst.active = i
                end
            end
        end
    end
    return state
end)

local function _sort_by_field(field, order, a, b)
    assert(order == "asc" or order == "desc")
    assert(field and a[field] and b[field])
    if order == "asc" then
        return a[field] < b[field]
    else
        return a[field] > b[field]
    end
end

local function _build_tabgroup_menu_grouptabs(w, group_name, field, order)
    local rows = {{"Group name", "Tab title", "URI", title = true}}
    local active = current_webview_in_group(w, group_name)

    local _tmp = {}
    local _gv = w2groups[w].groups[group_name]
    for i, v in grouptabs(w, group_name) do
        local tab = _gv.tabs[v] or { tab_hit = 1, atime = 0, ctime = os.time(), mtime = 0,  }
        _gv.tabs[v] = tab
        table.insert(_tmp, {
            v = v,
            hits = tab.tab_hit,
            atime = tab.atime,
            mtime = tab.mtime,
            ctime = tab.ctime,
            title = v.title or '',
            n = i,
        })
    end
    if field and order then
        table.sort(_tmp, function(a, b) return _sort_by_field(field, order, a, b) end)
    end

    for i, v in ipairs(_tmp) do
        local title = v.v.title or '*No title*'
        if v.v == active then
            table.insert(rows, {
                "<b>"..((i < 10 and i..' - ') or '')..group_name.."</b>",
                "<b>"..lousy.util.escape(title).."</b>",
                lousy.util.escape(v.v.uri),
                _group = group_name,
                _tab = v.v,
            })
        else
            table.insert(rows, {
                ((i < 10 and i..' - ') or '')..lousy.util.escape(group_name),
                lousy.util.escape(title),
                lousy.util.escape(v.v.uri),
                _group = group_name,
                _tab = v.v,
            })
        end
    end
    return rows
end

local function _build_tabgroup_menu_grouplist(w, field, order)
    local rows = {{ "Group name", "Number of tabs", title = true }}

    local _tmp = {}
    for g, gv in pairs(w2groups[w].groups) do
        table.insert(_tmp, {
            name = g,
            hits = gv.group_hit,
            atime = gv.atime,
            mtime = gv.mtime,
            ctime = gv.ctime,
        })
    end
    if field and order then
        table.sort(_tmp, function(a, b) return _sort_by_field(field, order, a, b) end)
    end
    for i, g in ipairs(_tmp) do
        if g.name == w2groups[w].active then
            table.insert(rows, {
                "<b>"..((i < 10 and i..' - ') or '')..lousy.util.escape(g.name).."</b>",
                w2groups[w].groups[g.name]._notebook:count(),
                _group = g.name,
            })
        else
            table.insert(rows, {
                ((i < 10 and i..' - ') or '')..lousy.util.escape(g.name),
                w2groups[w].groups[g.name]._notebook:count(),
                _group = g.name,
            })
        end
    end
    return rows
end

-- visual mode
local function build_tabgroup_menu(w, expand_group)
    local sort = settings.get_setting("tabgroups.sort_groups_by")
    local field, order = nil, nil
    if expand_group then
        sort = settings.get_setting("tabgroups.sort_tabs_by")
    end
    if sort then
        field, order = string.match(sort, "^%s*(%w+)%s+(%w+)")
    end

    if expand_group then
        return _build_tabgroup_menu_grouptabs(w, expand_group, field, order)
    else
        return _build_tabgroup_menu_grouplist(w, field, order)
    end
end

local _operation = setmetatable({}, {__mode = 'k'});

switch_tabgroup = function  (w, group)
    if group ~= w2groups[w].active then
        local g = w2groups[w].groups[group]
        local nb = g._notebook
        local group_nb = assert(w.tabs.parent)
        group_nb:switch(group_nb:indexof(nb))
        w.tablist:set_notebook(nb)
        w.tabs = nb

        -- changing name of active tabgroup and updating stats
        w2groups[w].active = group
        g.group_hit = g.group_hit + 1
        g.atime = os.time()

        -- if we switching to empty tabgroup -- let's open new default tab
        if nb:count() == 0 then
            w:new_tab(settings.get_setting("window.new_tab_page"), false)
        end

        -- copy-paste from window.lua, since that handler is only attached to the initial notebook
        w.view = nil
        -- Update widgets after tab switch
        luakit.idle_add(function ()
            -- Cancel if window already destroyed
            if not w.win or not w.view then return end
            w.view:emit_signal("switched-page")
            w:update_win_title()
        end)
    end
end

delete_tabgroup = function (w, group)
    assert(group)
    assert(type(group) == 'string')
    if number_of_tabgroups(w) == 1 then
        return nil
    else
        -- lets switch to another group
        if w2groups[w].active == group then
            switch_tabgroup(w, _select_next_opened_tabgroup(w, group))
        end

        local g = w2groups[w].groups[group]
        w.tabs.parent:remove(g._notebook)
        table.insert(_deleted_groups, g)
        w2groups[w].groups[group] = nil

        -- idle handler for cleaning removed notebooks
        luakit.idle_add(_cleaner)
    end
    return true
end

-- View tabgroups in list and switch between then
local function new_tabgroup(w)
    w:set_mode('tabgroup-menu-new')
end

local function rename_tabgroup(w)
    local row = w.menu:get()
    if row and row._group then
        w:set_mode('tabgroup-menu-rename')
    end
end

-- needed for forward declaration
local show_tabgroup_content, show_tabgroups, move_tab_to_tabgroup_menu

show_tabgroup_content = function (w, tabgroup_name)
    if type(tabgroup_name) == 'table' then
        tabgroup_name = nil
    end
    if not tabgroup_name then
        local row = w.menu:get()
        if row and row._group then
            tabgroup_name = row._group
        end
    end
    if tabgroup_name then
        local rows = build_tabgroup_menu(w, tabgroup_name)
        w.menu:build(rows)
        w.menu:update()
        local notify = _default_notify
        if number_of_tabgroups(w) > 1 then
            notify = notify ..", ".."m: move selected tab to another tabgroup, -: show list of groups"
        else
            notify = notify ..", ".."-: show list of groups"
        end
        w:notify(notify, false)
    end
end

show_tabgroups = function (w)
    local rows = build_tabgroup_menu(w)
    w.menu:build(rows)
    w.menu:update()
    local notify = _default_notify ..", ".. "+: show tabs in selected group"
    w:notify(notify, false)
end

local function switch_tabgroup_or_tab(w, _, m)
    local row = w.menu:get((m and m.count) and m.count+1 or nil)
    if row and row._group then
        w:set_mode()
        switch_tabgroup(w, row._group);
        if row._tab and row._tab ~= current_webview_in_group(w, w2groups[w].active) then
            local idx = webview2idx(row._tab)
            if idx then
                w:goto_tab(idx)
            end
        end
    end
end

local function open_tabgroup_menu(w, tabgroup_name)
    local expand = nil
    if tabgroup_name and type(tabgroup_name) == 'string' then
        expand = tabgroup_name
    end
    w:set_prompt()
    w:set_mode("tabgroup-menu", expand)
end

move_tab_to_tabgroup_menu = function (w)
    if number_of_tabgroups(w) > 1 then
        local row = w.menu:get()
        if row and row._group and row._tab then
            _operation[w] = { op = 'move', _group = row._group, _tab = row._tab, }
            w:set_mode('tabgroup-menu-select')
        end
    end
end

new_mode("tabgroup-menu-new", {
    enter = function (w)
        local groupname = _get_next_tabgroup_name(w)
        w:set_prompt("Enter name of new tabgroup > ")
        w:set_input(groupname)
    end,

    activate = function (w, name)
        if not w2groups[w].groups[name] then
            create_tabgroup(w, name)
        else
            w:notify("Tabgroup '"..name.."' already exists")
        end
        w:set_mode('tabgroup-menu')
    end,
})

modes.add_binds("tabgroup-menu-new", {
    { "<Escape>", "Return to `tabgroup-menu` mode.", open_tabgroup_menu },
})

new_mode("tabgroup-menu-rename", {
    enter = function (w)
        local row = w.menu:get()
        local groupname = row._group
        w:set_prompt("Enter new name of tabgroup '"..groupname.."' > ")
        w:set_input(groupname)
        _operation[w] = { op = 'rename', _group = groupname, }
    end,

    activate = function (w, new_name)
        local old_name = _operation[w]._group
        if old_name ~= new_name then
            w2groups[w].groups[new_name] = w2groups[w].groups[old_name]
            w2groups[w].groups[old_name] = nil
            if w2groups[w].active == old_name then
                w2groups[w].active = new_name
            end
            w.view:emit_signal("switched-page") -- a `tabgroup-changed` signal may be more appropriate,
                                                -- (both here, and in `switch_tabgroup` above)..
        end
        w:set_mode('tabgroup-menu')
    end,
})

modes.add_binds("tabgroup-menu-rename", {
    { "<Escape>", "Return to `tabgroup-menu` mode.", open_tabgroup_menu },
})

local function move_tab_to_tabgroup(w, view, group)
    local old_group = webview2group(view)
    if old_group.name ~= group then
        local tg = create_tabgroup(w, group)
        local stats = w2groups[w].groups[old_group.name].tabs[view]
        w2groups[w].groups[old_group.name]._notebook:remove(view)
        tg._notebook:insert(view)
        tg.tabs[view] = {
            tab_hit = stats.tab_hit,
            ctime = stats.ctime,
            atime = stats.atime,
            mtime = stats.mtime,
        }
    end
end

-- something that manages different operations when tabgroup select in tabgroup-menu-select mode
-- (so far only moving tabs between groups)
local _moving = false
local function select_tabgroup(w)
    local row = w.menu:get()
    if row and row._group then
        local op = assert(_operation[w])
        if op.op == 'move' and op._group and op._tab then
            if row._group ~= op._group then
                local tab = op._tab
                _moving = true
                w:set_mode()
                move_tab_to_tabgroup(w, tab, row._group)
                _moving = false
            else
                w:notify("Can't move tab to same tabgroup")
            end
            w:set_mode('tabgroup-menu')
        end
    end
end

new_mode("tabgroup-menu-select", {
    enter = function (w)
        local rows = build_tabgroup_menu(w)
        w.menu:build(rows)
        w:notify("Press <Return> to select tabgroup", false)
    end,

    leave = function (w)
        if not _moving then
            w:set_mode('tabgroup-menu')
        end
    end,
})

add_binds("tabgroup-menu-select",  lousy.util.table.join({
    { "<Return>", "Select tabgroup.", select_tabgroup },
}, menu_binds))

new_mode("tabgroup-menu", {
    enter = function (w, tabgroup_name)
        local rows = build_tabgroup_menu(w, tabgroup_name)
        _operation[w] = nil
        w.menu:build(rows)
        w:set_input()
        local notify = _default_notify
        if tabgroup_name then
            if number_of_tabgroups(w) > 1 then
                notify = notify ..", ".."m: move selected tab to another tabgroup, -: show list of groups"
            else
                notify = notify ..", ".."-: show list of groups"
            end
        else
            notify = notify ..", ".. "+: show tabs in selected group"
        end
        w:notify(notify, false)
    end,

    leave = function (w)
        w.menu:hide()
    end,
})

local _confirmation = setmetatable({}, {__mode = 'k'});
new_mode("delete-tg-ask-confirmation", {
    enter = function (w, confirmation_msg, row)
        w:warning(confirmation_msg..' (y/n)', false)
        _confirmation[w] = row
    end,

    leave = function (w)
        _confirmation[w] = nil
    end,
})

modes.add_binds("delete-tg-ask-confirmation", {
    { "y", "Answer 'Yes' on confirmation.", function (w)
        assert(_confirmation[w]._group)
        local deleted = delete_tabgroup(w, _confirmation[w]._group)
        open_tabgroup_menu(w)
        if not deleted then
            w:notify("Can't remove last tabgroup")
        end
    end },
    { "n", "Answer 'No' on confirmation.", function (w) open_tabgroup_menu(w) end },
    { "<Escape>", "Answer 'No' on confirmation.", function (w) open_tabgroup_menu(w) end },
})

add_binds("tabgroup-menu", lousy.util.table.join({
    { "<Return>", "Switch to tabgroup or tab in tabgroup.", switch_tabgroup_or_tab },
    { "n", "Create new tabgroup.", new_tabgroup },
    { "r", "Rename tabgroup.", rename_tabgroup },
    { "d", "Delete tabgroup.", function(w)
        local row = w.menu:get()
        if row and row._group then
            w:set_mode("delete-tg-ask-confirmation", "Really delete tabgroup '"..row._group.."'?", row)
        end
    end},
    { "+", "Open list of tabs in tabgroup.", show_tabgroup_content },
    { "-", "Hide list of tabs in tabgroup.", show_tabgroups },
    { "m", "Move tab to different tabgroup.", move_tab_to_tabgroup_menu },
    { "1", "Switch to first tab or tabgroup.", switch_tabgroup_or_tab, { count = 1 } },
    { "2", "Switch to second tab or tabgroup.", switch_tabgroup_or_tab, { count = 2 }  },
    { "3", "Switch to third tab or tabgroup.", switch_tabgroup_or_tab, { count = 3 }  },
    { "4", "Switch to forth tab or tabgroup.", switch_tabgroup_or_tab, { count = 4 }  },
    { "5", "Switch to fifth tab or tabgroup.", switch_tabgroup_or_tab, { count = 5 }  },
    { "6", "Switch to sixth tab or tabgroup.", switch_tabgroup_or_tab, { count = 6 }  },
    { "7", "Switch to seventh tab or tabgroup.", switch_tabgroup_or_tab, { count = 7 }  },
    { "8", "Switch to eighth tab or tabgroup.", switch_tabgroup_or_tab, { count = 8 }  },
    { "9", "Switch to ninth tab or tabgroup.", switch_tabgroup_or_tab, { count = 9 }  },
}, menu_binds))

add_binds("normal", {
    { "x", "Open tabgroup menu.", open_tabgroup_menu },
    { "X", "Show tabs in active tabgroup.", function (w) open_tabgroup_menu(w, w2groups[w].active)  end },
})

settings.register_settings({
    ["tabgroups.sort_groups_by"] = {
        type = "string",
        default = "name asc",
        validator = function(v)
            local field, order = string.match(v, "^%s*(%w+)%s+(%w+)")
            if not field or not order then return false end
            field, order = field:lower(), order:lower()
            field = ({name = true, atime = true, mtime = true, ctime = true, hits = true})[field]
            order = order == "asc" or order == "desc"
            return field and order
        end,
        desc = [=[ Sort order of groups in tabgroups menu.

Must be in the form "_field_ _order_", where _field_ is one of:

- `name`: group name
- `ctime`: time of group creation
- `mtime`: time of group modification (updated when adding or removing new tabs)
- `atime`: time of group accessing (updated when switching to this group)
- `hits`: number of times this group has been switched to

and _order_ is

- `asc`: sort in ascending order
- `desc`: sort in descending order
]=]
    },
    ["tabgroups.sort_tabs_by"] = {
        type = "string",
        default = "title asc",
        validator = function(v)
            local field, order = string.match(v, "^%s*(%w+)%s+(%w+)")
            if not field or not order then return false end
            field, order = field:lower(), order:lower()
            field = ({n = true, title = true, atime = true, mtime = true, ctime = true, hits = true})[field]
            order = order == "asc" or order == "desc"
            return field and order
        end,
        desc = [=[ Sort order of tabs in tabgroups menu.

Must be in the form "_field_ _order_", where _field_ is one of:

- `n`: tab index
- `title`: tab title
- `ctime`: time of tab creation
- `mtime`: time of tab modification (updated when URI changed)
- `atime`: time of tab accessing (updated when switching to this tab)
- `hits`: number of times this group has been switched to

and _order_ is

- `asc`: sort in ascending order
- `desc`: sort in descending order
]=]
    },
    ["tabgroups.switch_to_new_tab"] = {
        type = "boolean",
        default = true,
        desc = "Switch to new tabgroup after opening link to different tabgroup from popup menu or not"
    },
})


--- Open a given uri in a new tab in the given window.
--
-- @tparam table w The window the tab should be opened in.
-- @tparam tabgroup group The tabgroup the new tab should be added to.
-- @tparam string uri The uri to be opened.
-- @tparam table opts Additional options
_M.open_new_tab_in_tabgroup = function(...) return open_new_tab_in_tabgroup(...) end

--- Move tab to another tabgroup.
--
-- @tparam table w The window the tab should be opened in.
-- @tparam widget view The webview
-- @tparam tabgroup group The tabgroup the new tab should be added to.
_M.move_tab_to_tabgroup = function(...) return move_tab_to_tabgroup(...) end

--- Create a new tabgroup (or fetch one if `group_name` is in use).
--
-- @tparam table w The window to be associated with the tabgroup.
-- @tparam string group_name The name of the new group.
-- @treturn table The tabgroup, newly created or already existing.
_M.create_tabgroup = function(...) return create_tabgroup(...) end

--- Switch to specified tabgroup
--
-- @tparam table w A window.
-- @tparam string group The name of the tabgroup to switch to.
_M.switch_tabgroup = function(...) return switch_tabgroup(...) end

--- Delete the specified tabgroup
--
-- @tparam table w A window.
-- @tparam string group The name of the tabgroup to delete.
-- @treturn boolean nil if only one tabgroup exists, true otherwise.
_M.delete_tabgroup = function(...) return delete_tabgroup(...) end

--- Return the name of the current tabgroup.
--
-- @param object The object to set up for signals.
-- @tparam table w A window.
-- @treturn string The name of w's current tabgroup.
function _M.current_tabgroup (w)
    if w2groups and w2groups[w] and w2groups[w].active then
        return w2groups[w].active
    else
        return "No Tabgroup Selected"
    end
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
