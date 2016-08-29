local adblock   = require("adblock")
local lousy     = lousy
local util      = lousy.util
local add_binds, add_cmds = add_binds, add_cmds
local chrome    = chrome
local type      = type
local tostring  = tostring
local tonumber  = tonumber
local pairs     = pairs
local ipairs    = ipairs
local string    = string
local table     = table
local window    = window
local webview   = webview
local error_page = require "error_page"

module("adblock_chrome")

-- Templates
list_template_enabled = [==[
    <tr>
        <td>{title}</td>
        <td>B: {black}</td><td>W: {white}</td><td>I: {ignored}</td>
        <td><a href="{uri}">{name}</a></td>
        <td class="state_{state}">{state}</td>
        <td><a class=disable href=# onclick="adblock_list_toggle({id}, false)">Disable</a></td>
    </tr>
]==]

list_template_disabled = [==[
    <tr>
        <td>{title}</td>
        <td></td><td></td><td></td>
        <td><a href="{uri}">{name}</a></td>
        <td class="state_{state}">{state}</td>
        <td><a class=enable href=# onclick="adblock_list_toggle({id}, true)">Enable</a></td>
    </tr>
]==]

toggle_button_template = [==[
    <input type="button" class="button" onclick="adblock_toggle({state})" value="{label}" />
]==]

html_template = [==[
    <html>
    <head>
        <title>{title}</title>
        <style type="text/css">
            {style}
        </style>
    </head>
    <body>
        <header id="page-header">
            <h1>AdBlock</h1>
            <span class=state_{state}>{state}</span>
            <span>B: {black} / W: {white} / I: {ignored}</span>
            <div class="rhs">{toggle}</div>
        </header>
        <div class="content-margin">
            <table>
                <thead>
                    <th>File</th>
                    <th colspan=3>Rules in use</th>
                    <th>Update URL</th>
                    <th>State</th>
                    <th>Actions</th>
                </thead>
                <tbody>
                    {links}
                </tbody>
            </table>
        </div>
    </body>
    </html>
]==]

-- Template subs
html_page_title = "AdBlock filters"

html_style = [===[
    table {
        font-size: 1.0em;
        width: 100%;
    }
    th {
        text-align: left;
        font-size: 1.6em;
        font-weight: 100;
        margin: 1em 0 0.5em 0.5em;
        -webkit-user-select: none;
        cursor: default;
    }
    td {
        font-size: 1.3em;
    }
    th, td {
        white-space: nowrap;
    }
    th:not(:nth-last-child(3)),
    td:not(:nth-last-child(3)) {
        width: 1px;
    }
    th:nth-last-child(3),
    td:nth-last-child(3) {
        overflow: hidden;
        text-overflow: ellipsis;
        max-width: 100px;
        width: 100%;
    }
    td + td, th + th {
        padding-left: 1rem;
    }
    header > span {
        padding: 1em;
    }
    .state_Enabled {
        color: #799D6A;
        font-weight: bold;
    }
    .state_Disabled {
        color: #CF6A4C;
        font-weight: bold;
    }
]===]


-- Functions
-- Refresh open filters views (if any)
function refresh_views()
    for _, w in pairs(window.bywidget) do
        for _, v in ipairs(w.tabs.children) do
            if string.match(v.uri or "", "^luakit://adblock/?") then
                v:reload()
            end
        end
    end
end

-- Enable adblock to refresh this chrome view.
adblock.refresh_views = refresh_views

-- URI of the chrome page
chrome_page    = "luakit://adblock/"

--- Shows the chrome page in the given view.
chrome.add("adblock", function (view, meta)
    local uri = chrome_page

    local id = 0
    local lists = {}
    for _, list in pairs(adblock.subscriptions) do
        id = id + 1
        list['id'] = id
        lists[list.title] = list
    end

    local links = {}
    for _, list in pairs(lists) do
        local link_subs = {
            uri     = list.uri,
            id      = list.id,
            name    = util.escape(list.uri),
            title   = list.title,
            white   = list.white,
            black   = list.black,
            ignored = list.ignored,
            state   = util.table.hasitem(list.opts, "Enabled") and "Enabled" or "Disabled"
        }
        local list_template = list_template_disabled
        -- Show rules count only when enabled this list and have read its rules
        if util.table.hasitem(list.opts, "Enabled") and list.white and list.black and list.ignored then
            -- For totals count items only once (protection from multi-tagging by several opts confusion)
            list_template = list_template_enabled
        end
        local link = string.gsub(list_template, "{(%w+)}", link_subs)
        table.insert(links, link)
    end

    local rulescount = { black = 0, white = 0, ignored = 0 }
    for _, list in pairs(adblock.rules) do
        if list.black and list.white and list.ignored then
            rulescount.black, rulescount.white, rulescount.ignored = rulescount.black + list.black, rulescount.white + list.white, rulescount.ignored + list.ignored
        end
    end

    local toggle_button_subs = {
        state = adblock.state() == "Disabled" and "true" or "false",
        label = adblock.state() == "Disabled" and "Enable" or "Disable",
    }

    local html_subs = {
        links   = table.concat(links, "\n\n"),
        title  = html_page_title,
        style  = chrome.stylesheet .. html_style,
        state = adblock.state(),
        white   = rulescount.white,
        black   = rulescount.black,
        ignored = rulescount.ignored,
        toggle = string.gsub(toggle_button_template, "{(%w+)}", toggle_button_subs),
    }

    local html = string.gsub(html_template, "{(%w+)}", html_subs)
    return html
end,
nil,
{
    adblock_toggle = function (_, enable)
        if enable then adblock.enable() else adblock.disable() end
    end,

    adblock_list_toggle = function (_, id, enable)
        adblock.list_set_enabled(id, enable)
    end,
})

navigation_blocked_css_tmpl = [===[
    body {
        background-color: #ddd;
        margin: 0;
        padding: 0;
        display: flex;
        align-items: center;
        justify-content: center;
    }

    #errorContainer {
        background: #fff;
        min-width: 35em;
        max-width: 35em;
        padding: 2.5em;
        border: 2px solid #aaa;
        -webkit-border-radius: 5px;
    }

    #errorTitleText {
        font-size: 120%;
        font-weight: bold;
        margin-bottom: 1em;
    }

    .errorMessage {
        font-size: 90%;
    }

    p {
        margin: 0;
    }
]===]

webview.init_funcs.navigation_blocked_page_init = function(view, w)
    view:add_signal("navigation-blocked", function(v, w, uri)
        error_page.show_error_page(v, {
            style = navigation_blocked_css_tmpl,
            heading = "Page blocked",
            content = [==[
                <div class="errorMessage">
                    <p>AdBlock has prevented the page at {uri} from loading</p>
                </div>
            ]==],
            buttons = {},
            uri = uri,
        })
        return true
    end)
end

-- Add chrome binds.
local key, buf = lousy.bind.key, lousy.bind.buf
add_binds("normal", {
    buf("^ga$", function (w)
        w:navigate(chrome_page)
    end),

    buf("^gA$", function (w, b, m)
        for i=1, m.count do
            w:new_tab(chrome_page)
        end
    end, {count=1}),
})

-- Add chrome commands.
local cmd = lousy.bind.cmd
add_cmds({
    cmd("adblock", function (w)
        w:navigate("luakit://adblock/")
    end),
})
