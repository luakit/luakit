#!./luakit -c

require("math")
require("mode")
require("bind")

-- Widget construction aliases
function eventbox() return widget{type="eventbox"} end
function hbox()     return widget{type="hbox"}     end
function label()    return widget{type="label"}    end
function notebook() return widget{type="notebook"} end
function vbox()     return widget{type="vbox"}     end
function webview()  return widget{type="webview"}  end
function window()   return widget{type="window"}   end
function entry()    return widget{type="entry"}    end

-- Keep a list of windows and data objects
windows = {}

-- Widget type-specific default settings
widget.add_signal("new", function(w)
    w:add_signal("init", function(w)
        if w.type == "window" then
            -- Call the quit function if this was the last window left
            w:add_signal("destroy", function ()
                if #luakit.windows == 0 then luakit.quit() end
            end)
        elseif w.type == "label" or w.type == "entry" then
            w.font = "monospace normal 9"
        end
    end)
end)

-- Returns a nice window title
function mktitle(view)
    if not view:get_prop("title") and not view.uri then return "luakit" end
    return (view:get_prop("title") or "luakit") .. " - " .. (view.uri or "about:blank")
end

-- Returns true if the given view is the currently active view
function iscurrent(nbook, view)
    return nbook:current() == nbook:indexof(view)
end

function mktabcount(nbook, i)
    return string.format("[%d/%d]", i or nbook:current(), nbook:count())
end

-- Returns a vim-like scroll indicator
function scroll_parse(view)
    val, max = view:get_vscroll()
    if max == 0 then
        return "All"
    elseif val == 0 then
        return "Top"
    elseif val == max then
        return "Bot"
    else
        return string.format("%2d%%", (val/max) * 100)
    end
end

function autohide(nbook, n)
    if not n then n = nbook:count() end
    if n == 1 then
        nbook.show_tabs = false
    else
        nbook.show_tabs = true
    end
end

function progress_update(w, view, p)
    if not p then p = view:get_prop("progress") end
    if not view:loading() or p == 1 then
        w.sbar.loaded:hide()
    else
        w.sbar.loaded:show()
        w.sbar.loaded.text = string.format("(%d%%)", p * 100)
    end
end

function new_tab(w, uri)
    view = webview()
    w.tabs:append(view)
    autohide(w.tabs)

    -- Attach webview signals
    view:add_signal("title-changed", function (v)
        w.tabs:set_title(v, v:get_prop("title") or "(Untitled)")
        if iscurrent(w.tabs, v) then
            w.win.title = mktitle(v)
        end
    end)

    view:add_signal("property::uri", function(v)
        if not w.tabs:get_title(v) then
            w.tabs:set_title(v, v.uri or "about:blank")
        end

        if iscurrent(w.tabs, v) then
            w.sbar.uri.text = v.uri or "about:blank"
        end
    end)

    view:add_signal("key-press", function ()
        -- Prevent keys from hitting the webview widget if not in insert mode
        if mode.get(w.win) ~= "insert" then return true end
    end)

    view:add_signal("load-start", function (v)
        if iscurrent(w.tabs, v) then
            progress_update(w, v, 0)
            mode(w.win)
        end
    end)
    view:add_signal("progress-update", function (v)
        if iscurrent(w.tabs, v) then progress_update(w, v) end
    end)

    view:add_signal("expose", function(v)
        if iscurrent(w.tabs, v) then
            w.sbar.scroll.text = scroll_parse(v)
        end
    end)

    -- Navigate to uri
    view.uri = uri

    return view
end

function parse_scroll(current, max, value)
    if type(value) == "string" then
        -- Match absolute "20px"
        if string.match(value, "^%d+px$") then
            value = tonumber(string.match(value, "^(%d+)px$"))
        -- Match absolute "20%"
        elseif string.match(value, "^%d%%$") then
            value = math.floor(max * (tonumber(string.match(value, "^(%d+)%%$")) / 100))
        -- Match relative "+20px" or "-20px"
        elseif string.match(value, "^[\-\+]%d+px") then
            value = current + tonumber(string.match(value, "^([\-\+]%d+)px"))
        -- Match relative "+20%" or "-20%"
        elseif string.match(value, "^[\-\+]%d+%%$") then
            value = math.floor(current + (max * (tonumber(string.match(value, "^([\-\+]%d+)%%$")) / 100)))
        else
            value = nil
        end
    elseif type(value) ~= "number" then
        value = nil
    end
    return value
end

function vscroll(view, value)
    local current, max = view:get_vscroll()
    value = parse_scroll(current, max, value)
    view:set_vscroll(value)
end

function hscroll(view, value)
    local current, max = view:get_hscroll()
    value = parse_scroll(current, max, value)
    view:set_hscroll(value)
end

-- Add key bindings to be used across all windows
modebinds = {
    all = {
        bind.key({}, "Escape",  function(w) mode(w.win) end),
    },
    normal = {
        bind.key({}, "i",       function (w) mode(w.win, "insert") end),
        bind.key({}, ":",       function (w) mode(w.win, "command") end),

        bind.key({}, "h",       function (w, v) hscroll(v, "-20px") end),
        bind.key({}, "j",       function (w, v) vscroll(v, "+20px") end),
        bind.key({}, "k",       function (w, v) vscroll(v, "-20px") end),
        bind.key({}, "l",       function (w, v) hscroll(v, "+20px") end),
        bind.key({}, "Left",    function (w, v) hscroll(v, "-20px") end),
        bind.key({}, "Down",    function (w, v) vscroll(v, "+20px") end),
        bind.key({}, "Up",      function (w, v) vscroll(v, "-20px") end),
        bind.key({}, "Right",   function (w, v) hscroll(v, "+20px") end),
    },
    command = { },
    insert = { },
}

-- Construct new window
function new_window(uris)
    -- Widget & state variables
    local w = {
        win = window(),
        layout = vbox(),
        tabs = notebook(),
        -- Status bar widgets
        sbar = {
            layout = hbox(),
            ebox = eventbox(),
            uri = label(),
            loaded = label(),
            sep = label(),
            rlayout = hbox(),
            rebox = eventbox(),
            tabi = label(),
            scroll = label(),
        },
        -- Input bar widgets
        ibar = {
            layout = hbox(),
            ebox = eventbox(),
            prompt = label(),
            input = entry(),
        },
    }

    -- Pack widgets
    w.win:set_child(w.layout)
    w.sbar.ebox:set_child(w.sbar.layout)
    w.layout:pack_start(w.tabs, true, true, 0)
    w.sbar.layout:pack_start(w.sbar.uri, false, false, 0)
    w.sbar.layout:pack_start(w.sbar.loaded, false, false, 0)
    w.sbar.layout:pack_start(w.sbar.sep, true, true, 0)

    -- Put the right-most labels in something backgroundable
    w.sbar.rlayout:pack_start(w.sbar.tabi, false, false, 0)
    w.sbar.rlayout:pack_start(w.sbar.scroll, false, false, 2)
    w.sbar.rebox:set_child(w.sbar.rlayout)

    w.sbar.layout:pack_start(w.sbar.rebox, false, false, 0)
    w.layout:pack_start(w.sbar.ebox, false, false, 0)

    -- Pack input bar
    w.ibar.layout:pack_start(w.ibar.prompt, false, false, 0)
    w.ibar.layout:pack_start(w.ibar.input, true, true, 0)
    w.ibar.ebox:set_child(w.ibar.layout)
    w.layout:pack_start(w.ibar.ebox, false, false, 0)

    w.sbar.uri.fg = "#fff"
    w.sbar.uri.selectable = true
    w.sbar.loaded.fg = "#888"
    w.sbar.loaded:hide()
    w.sbar.rebox.bg = "#000"
    w.sbar.scroll.fg = "#fff"
    w.sbar.scroll.text = "All"
    w.sbar.tabi.text = "[0/0]"
    w.sbar.tabi.fg = "#fff"
    w.sbar.ebox.bg = "#000"

    w.ibar.input.show_frame = false
    w.ibar.input.bg = "#fff"
    w.ibar.input.fg = "#000"

    w.ibar.ebox.bg = "#fff"
    w.ibar.prompt.text = "Hello"
    w.ibar.prompt.fg = "#000"

    -- Attach notebook signals
    w.tabs:add_signal("page-added", function(nbook, view, idx)
        w.sbar.tabi.text = mktabcount(nbook)
    end)
    w.tabs:add_signal("switch-page", function(nbook, view, idx)
        w.sbar.tabi.text = mktabcount(nbook, idx)
        w.sbar.uri.text = view.uri or "about:blank"
        w.win.title = mktitle(view)
        progress_update(w, view)
        autohide(nbook)
    end)

    w.win:add_signal("key-press", function(win, mods, key)
        -- Current webview
        local view = w.tabs:atindex(w.tabs:current())

        -- Try mode specific binds
        local binds = modebinds[mode.get(win)]
        if binds and #binds then
            if bind.hit(binds, mods, key, w, view) then return true end
        end

        -- Now try binds in the "all" mode
        binds = modebinds.all
        if binds and #binds then
            if bind.hit(binds, mods, key, w, view) then return true end
        end
    end)

    -- Mode specific actions
    w.win:add_signal("mode-changed", function(win, mode)
        if mode == "normal" then
            w.ibar.prompt.text = ""
            w.ibar.prompt:show()
            w.ibar.input:hide()
            w.ibar.input.text = ""
        elseif mode == "insert" then
            w.ibar.input:hide()
            w.ibar.input.text = ""
            w.ibar.prompt.text = "-- INSERT --"
            w.ibar.prompt:show()
        elseif mode == "command" then
            w.ibar.prompt:hide()
            w.ibar.prompt.text = ""
            w.ibar.input.text = ":"
            w.ibar.input:show()
            w.ibar.input:focus()
            w.ibar.input:set_position(-1)
        end
    end)

    w.ibar.input:add_signal("changed", function()
        if mode.get(w.win) == "command" and not string.match(w.ibar.input.text, "^:") then
            mode(w.win)
        end
    end)

    -- Populate notebook
    for _, uri in ipairs(uris) do
        new_tab(w, uri)
    end

    -- Make sure something is loaded
    if w.tabs:count() == 0 then
        new_tab(w, "http://github.com/mason-larobina/luakit")
    end

    -- Set initial mode
    mode(w.win)

    return w
end

new_window(uris)
