--- Simple URI-based content filter - chrome page.
--
-- This module allows you to configure the `adblock` module with a simple
-- graphical webpage at <luakit://adblock/>. You can
-- currently:
--
--  - enable/disable the adblocker globally, and
--  - enable/disable individual filter lists.
--
-- The adblocker page also shows some statistics about the number of adblock
-- rules in effect.
--
-- @module adblock_chrome
-- @author Henning Hasemann
-- @author Mason Larobina
-- @author Plaque FCC
-- @copyright 2010 Henning Hasemann
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2010 Plaque FCC <Reslayer@ya.ru>

local adblock    = require("adblock")
local lousy      = require("lousy")
local chrome     = require("chrome")
local window     = require("window")
local webview    = require("webview")
local error_page = require("error_page")
local modes      = require("modes")
local add_binds, add_cmds = modes.add_binds, modes.add_cmds

local _M = {}

--- HTML template for enabled adblock list.
-- @type string
-- @readwrite
_M.list_template_enabled = [==[
    <tr>
        <td>{title}</td>
        <td>B: {black}</td><td>W: {white}</td><td>I: {ignored}</td>
        <td><a href="{uri}">{name}</a></td>
        <td class="state_{state}">{state}</td>
        <td><a class=disable href=# onclick="adblock_list_toggle({id}, false)">Disable</a></td>
    </tr>
]==]

--- HTML template for disabled adblock list.
-- @type string
-- @readwrite
_M.list_template_disabled = [==[
    <tr>
        <td>{title}</td>
        <td></td><td></td><td></td>
        <td><a href="{uri}">{name}</a></td>
        <td class="state_{state}">{state}</td>
        <td><a class=enable href=# onclick="adblock_list_toggle({id}, true)">Enable</a></td>
    </tr>
]==]

--- HTML template for adblock state toggle button.
-- @type string
-- @readwrite
_M.toggle_button_template = [==[
    <input type="button" class="button" onclick="adblock_toggle({state})" value="{label}" />
]==]

--- HTML template for adblock chrome page content.
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

--- Title for the adblock chrome page.
-- @type string
-- @readwrite
_M.html_page_title = "AdBlock filters"

--- CSS applied to the adblock chrome page.
-- @type string
-- @readwrite
_M.html_style = [===[
    table {
        width: 100%;
        margin: 1em 0;
    }
    th {
        text-align: left;
        font-size: 1.3em;
        font-weight: 100;
        margin: 1em 0 0.5em 0.5em;
        -webkit-user-select: none;
        cursor: default;
    }
    td {
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
local function refresh_views()
    for _, w in pairs(window.bywidget) do
        for _, v in ipairs(w.tabs.children) do
            if string.match(v.uri or "", "^luakit://adblock/?") then
                v:reload()
            end
        end
    end
end

adblock.refresh_views = refresh_views

--- URI of the adblock chrome page.
-- @type string
-- @readwrite
_M.chrome_page = "luakit://adblock/"

-- Shows the chrome page in the given view.
chrome.add("adblock", function ()
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
            name    = lousy.util.escape(list.uri),
            title   = list.title,
            white   = list.white,
            black   = list.black,
            ignored = list.ignored,
            state   = lousy.util.table.hasitem(list.opts, "Enabled") and "Enabled" or "Disabled"
        }
        local list_template = _M.list_template_disabled
        -- Show rules count only when enabled this list and have read its rules
        if lousy.util.table.hasitem(list.opts, "Enabled") and list.white and list.black and list.ignored then
            -- For totals count items only once (protection from multi-tagging by several opts confusion)
            list_template = _M.list_template_enabled
        end
        local link = string.gsub(list_template, "{(%w+)}", link_subs)
        table.insert(links, link)
    end

    local rulescount = { black = 0, white = 0, ignored = 0 }
    for _, list in pairs(adblock.rules) do
        if list.black and list.white and list.ignored then
            rulescount.black, rulescount.white = rulescount.black + list.black, rulescount.white + list.white
            rulescount.ignored = rulescount.ignored + list.ignored
        end
    end

    local toggle_button_subs = {
        state = tostring(not adblock.enabled),
        label = (not adblock.enabled) and "Enable" or "Disable",
    }

    local html_subs = {
        links   = table.concat(links, "\n\n"),
        title  = _M.html_page_title,
        style  = chrome.stylesheet .. _M.html_style,
        state = adblock.enabled and "Enabled" or "Disabled",
        white   = rulescount.white,
        black   = rulescount.black,
        ignored = rulescount.ignored,
        toggle = string.gsub(_M.toggle_button_template, "{(%w+)}", toggle_button_subs),
    }

    local html = string.gsub(_M.html_template, "{(%w+)}", html_subs)
    return html
end,
nil,
{
    adblock_toggle = function (_, enable)
        adblock.enabled = enable
    end,

    adblock_list_toggle = function (_, id, enable)
        adblock.list_set_enabled(id, enable)
    end,
})

--- CSS for error page shown when page navigation is blocked.
-- @type string
-- @readwrite
_M.navigation_blocked_css_tmpl = [===[
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

luakit.register_scheme("adblock-blocked")
webview.add_signal("init", function (view)
    view:add_signal("scheme-request::adblock-blocked", function (v, uri, request)
        uri = uri:gsub("^adblock%-blocked:", "")
        error_page.show_error_page(v, {
            style = _M.navigation_blocked_css_tmpl,
            heading = "Page blocked",
            content = [==[
                <div class="errorMessage">
                    <p>AdBlock has prevented the page at {uri} from loading</p>
                </div>
            ]==],
            buttons = {{
                label = "Continue anyway",
                callback = function(vv)
                    webview.modify_load_block(v, "adblock", true)
                    webview.set_location(vv, uri)
                    adblock.whitelist_domain_access(lousy.uri.parse(uri).host)
                end
            }},
            uri = uri,
            request = request,
        })
        return
    end)
end)

-- Add chrome binds.
add_binds("normal", {
    { "ga", "Open <luakit://adblock/> in the current tab.",
        function (w) w:navigate(_M.chrome_page) end },
    { "gA", "Open <luakit://adblock/> in a new tab.",
        function (w, m)
            for _=1, m.count do
                w:new_tab(_M.chrome_page)
            end
        end, {count=1} },
})

-- Add chrome commands.
add_cmds({
    { ":adblock", "Open <luakit://adblock/> in a new tab.",
        function (w) w:new_tab(_M.chrome_page) end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
