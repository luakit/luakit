--- Luakit log viewer.
--
-- This module supplies the <luakit://log/> chrome page, which displays the most
-- recent log messages.
--
-- @module log_chrome
-- @author Aidan Holm
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local chrome = require "chrome"
local window = require "window"
local lousy = require "lousy"
local theme = lousy.theme.get()
local modes = require "modes"

local _M = {}

--- The size of the buffer in which the most recent log messages are stored.
-- This is the maximum number of entries that will be shown on the log page.
-- @type number
-- @default 500
-- @readwrite
_M.buffer_size = 500

local log_views = {}
local log_entries = {}
local append_timer = timer{interval = 100}

--- HTML template for luakit log chrome page content.
-- @type string
-- @readwrite
_M.html_template = [==[
    <html>
    <head>
        <title>{title}</title>
        <style type="text/css">
            {style}
        </style>
    </head>
    <body>
        <header id="page-header">
            <h1>Luakit log</h1>
        </header>
        <div class="content-margin">
            <table>
                <thead>
                    <th>Time</th>
                    <th>Level</th>
                    <th>Group</th>
                    <th>Message</th>
                </thead>
                <tbody>
                    {rows}
                </tbody>
            </table>
        </div>
    </body>
    </html>
]==]

--- Title for the log chrome page.
-- @type string
-- @readwrite
_M.html_page_title = "Luakit log"

--- CSS applied to the log chrome page.
-- @type string
-- @readwrite
_M.html_style = [===[
    table {
        margin: 0;
        border-collapse:collapse;
        table-layout: fixed;
    }
    th {
        text-align: left;
        font-size: 1.3em;
        font-weight: 100;
        margin: 1em 0 0.5em 0.5em;
        -webkit-user-select: none;
        cursor: default;
    }
    th, td {
        white-space: nowrap;
    }

    th { padding: 0.5rem 0.5rem 0.2em; }
    td { padding: 0.2rem 0.5rem; }
    th:first-child, td:first-child { padding-left: 1rem; }
    td:last-child, th:last-child { padding-right: 1rem; }

    th:nth-child(1), td:nth-child(1) { min-width: 120px; }
    th:nth-child(2), td:nth-child(2) { min-width: 80px; }
    th:nth-child(3), td:nth-child(3) { min-width: 250px; }
    th:nth-child(4), td:nth-child(4) { width: 100%; }

    tr:hover > td { background: #f8f8f8; }
    tr > td { background: linear-gradient(180deg, #fafafa 0%, #fff 100%); }

    tr.level-verbose { color: #666; }
    tr.level-warn > td { background: #FFB964; }
    tr.level-warn:hover > td { background: #F9B561; }
    tr.level-error > td { background: #D87050; }
    tr.level-error:hover > td { background: #CF6A4C; }

    td.level { }
    td { font-family: monospace; }
    td { vertical-align: top; }
    td.msg > pre { margin: 0; }

    .content-margin { padding: 3.5em 0 0 0; }
]===]

local log_entry_fmt = ([==[
        <tr class="level-{llevel} group-{groupkey}">
            <td class=level>{time}</td>
            <td class=llevel>{level}</td>
            <td class=group>{group}</td>
            <td class=msg><pre>{msg}</pre></td>
        </tr>
    ]==]):gsub("\n +", ""):gsub("^ +", ""):gsub(" +$", "")
local build_log_entry_html = function (entry)
    assert(entry)
    return log_entry_fmt:gsub("{(%w+)}", {
        time = string.format("%012f", entry.time),
        llevel = entry.level,
        level = entry.level:gsub("^%l", string.upper),
        group = entry.group,
        groupkey = entry.group:gsub("/","-"),
        msg = entry.msg,
    })
end

local sync_view = function (v)
    local unsynced_count = log_views[v].unsynced_count
    local rows = {}
    for i=#log_entries-unsynced_count+1,#log_entries do
        rows[#rows+1] = build_log_entry_html(assert(log_entries[i]))
    end
    log_views[v].unsynced_count = 0

    local js = [=[
        var html = %s, num_rows = %d;
        var tbody = document.querySelector("tbody");
        tbody.insertAdjacentHTML('beforeend', html);
        for (var i = tbody.childElementCount; i > num_rows; i-- ) {
            tbody.firstElementChild.remove();
        }
    ]=]
    for i, row in ipairs(rows) do
        -- only the msg contains literal newlines: escape them
        -- has to be done outside of %q formatting
        row = row:gsub("\n", "<br>")
        rows[i] = string.format("%q", row):gsub("\\\n", "\n")
    end
    js = js:format(table.concat(rows,"+"), _M.buffer_size)

    v:eval_js(js, { no_return = true, callback = function (_, err)
        assert(not err, err)
    end})
end

local log_view_destroy_cb = function (view)
    log_views[view] = nil
end

append_timer:add_signal("timeout", function ()
    if append_timer.started then append_timer:stop() end

    local views = {}
    for v, _ in pairs(log_views) do
        if string.match(v.uri or "", "^luakit://log/?") then
            if not v.is_loading then views[#views+1] = v end
        else
            log_views[v] = nil
            v:remove_signal("destroy", log_view_destroy_cb)
        end
    end

    for _, v in ipairs(views) do
        sync_view(v)
    end
end)

chrome.add("log", function (view)
    local rows = {}
    for i, entry in ipairs(log_entries) do
        rows[i] = build_log_entry_html(entry)
    end

    local html_subs = {
        title = _M.html_page_title,
        style = chrome.stylesheet .. _M.html_style,
        rows = table.concat(rows, "\n"),
    }
    local html = string.gsub(_M.html_template, "{(%w+)}", html_subs)
    log_views[view] = { unsynced_count = 0 }
    view:add_signal("destroy", log_view_destroy_cb)
    return html
end)

--- Format string which defines the appearance of the error/warning widget.
-- This is passed to `string.format` with the number of errors as a
-- numerical argument, the result of which is substituted into @ref{widget_format}.
-- @type string
-- @readwrite
_M.widget_error_format = "<span color='#f00'>E: %d</span>"

--- Format string which defines the appearance of the error/warning widget.
-- This is passed to `string.format` with the number of warnings as a
-- numerical argument, the result of which is substituted into @ref{widget_format}.
-- @type string
-- @readwrite
_M.widget_warning_format = "<span color='#f60'>W: %d</span>"

--- Format string which defines the appearance of the error/warning widget.
-- This combines the error and warning sub-format strings. `{errors}` will be
-- replaced with the result of formatting @ref{widget_error_format}, or the
-- empty string if there have been no errors. Likewise, `{warnings}` will be
-- replaced with the result of formatting @ref{widget_warning_format}, or the
-- empty string if there have been no warnings
-- @type string
-- @readwrite
_M.widget_format = " {errors} {warnings} "

local widgets = {}
local error_count, warning_count = 0, 0
local function update_widgets()
    local text = string.gsub(_M.widget_format, "{(%w+)}", {
            errors = error_count > 0 and string.format(_M.widget_error_format, error_count) or "",
            warnings = warning_count > 0 and string.format(_M.widget_warning_format, warning_count) or "",
        })
    local tooltip = string.format("Errors: %d, Warnings: %d", error_count, warning_count)
    for _, notif in ipairs(widgets) do
        notif.text = text
        notif.tooltip = tooltip
        notif:show()
    end
end

local function widget_click_cb(notif)
    error_count, warning_count = 0, 0
    for _, n in ipairs(widgets) do
        n:hide()
    end
    local w = window.ancestor(notif)
    if w then w:new_tab("luakit://log/", { switch = true }) end
end

msg.add_signal("log", function (time, level, group, msg)
    table.insert(log_entries, {
        time = time,
        level = level,
        group = group,
        msg = msg:gsub("^%l", string.upper):gsub(string.char(27) .. '%[%d+m', '')
    })

    if level == "warn" then
        warning_count = warning_count + 1
        update_widgets()
    elseif level == "error" then
        error_count = error_count + 1
        update_widgets()
    end

    for _, t in pairs(log_views) do
        t.unsynced_count = math.min(t.unsynced_count + 1, _M.buffer_size)
    end

    if next(log_views) and not append_timer.started then
        append_timer:start()
    end
    while #log_entries > _M.buffer_size do table.remove(log_entries, 1) end
end)

--- Construct a new error/warning status bar widget.
-- This widget will stay hidden, until a luakit error or warning is logged.
-- Once shown, clicking on the widget will hide it and all other such widgets.
-- @treturn widget The newly-constructed status bar widget.
_M.widget = function ()
    local notif, ebox = widget{type="label"}, widget{type="eventbox"}
    notif:hide()
    notif.fg = theme.sbar_notif_fg
    notif.font = theme.sbar_notif_font
    table.insert(widgets, notif)
    notif:add_signal("destroy", function ()
        table.remove(widgets, lousy.util.table.hasitem(widgets, notif))
    end)
    update_widgets()
    ebox.child = notif
    ebox:add_signal("button-release", widget_click_cb)
    return ebox
end

modes.add_cmds({
    { ":log", "Open <luakit://log/> in a new tab.", function (w)
        w:new_tab("luakit://log/")
    end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
