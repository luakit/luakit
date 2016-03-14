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


module("adblock_chrome")

-- Templates
rules_template = [==[
    {black} rules blacklisting, {white} rules whitelisting, {ignored} rules ignored.
]==]

block_template = [==[
    <div class="tag">
        <h1>{opt}</h1>
        <ul>{links}</ul>
    </div>
]==]

list_template_enabled = [==[
    <li>
        {title}:
        <i>(b{black}/w{white}/i{ignored}), </i>
        <a href="{uri}">{name}</a>
        <span class="id">{id}</span>
    </li>
]==]

list_template_disabled = [==[
    <li>
        {title}:
        <a href="{uri}">{name}</a>
        <span class="id">{id}</span>
    </li>
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
            <div class="rhs">{toggle}</div>
        </header>
        <div class="content-margin">
            <div>
                AdBlock is in <b>{mode}</b> mode.{rules}
                <hr>
                {opts}
            </div>
        </div>
    </body>
    </html>
]==]

-- Template subs
html_page_title = "AdBlock filters"

html_style = [===[
    header > span {
        padding: 1em 1em 1em 1em;
    }
    span.state_Enabled {
        color: #799D6A;
        font-weight: bold;
    }
    span.state_Disabled {
        color: #CF6A4C;
        font-weight: bold;
    }
    .content-margin > div {
        font-family: monospace;
        line-height: 1.5em;
        font-size: 12pt;
    }
    div.tag {
        width: 100%;
        padding: 0px;
        margin: 0 0 25px 0;
        clear: both;
    }
    span.id {
        font-size: small;
        color: #333333;
        float: right;
    }
    .tag ul {
        padding: 0;
        margin: 0;
        list-style-type: none;
    }
    .tag h1 {
        font-size: 12pt;
        font-weight: bold;
        font-style: normal;
        font-variant: small-caps;
        padding: 0 0 5px 0;
        margin: 0;
        color: #CC3333;
        border-bottom: 1px solid #aaa;
    }
    .tag a:link {
        color: #0077bb;
        text-decoration: none;
    }
    .tag a:hover {
        color: #0077bb;
        text-decoration: underline;
    }
]===]


-- Functions
-- Refresh open filters views (if any)
function refresh_views()
    for _, w in pairs(window.bywidget) do
        for _, v in ipairs(w.tabs.children) do
            if string.match(v.uri, "^luakit://adblock/?") then
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
    -- Get a list of all the unique tags in all the lists and build a
    -- relation between a given tag and a list of subscriptions with that tag.
    local opts = {}
    local id = 0
    for _, list in pairs(adblock.subscriptions) do
        id = id + 1
        list['id'] = id
        for _, opt in ipairs(list.opts) do
            if not opts[opt] then opts[opt] = {} end
            opts[opt][list.title] = list
        end
    end

    -- For each opt build a block
    local lines = {}
    for _, opt in ipairs(util.table.keys(opts)) do
        local links = {}
        for _, title in ipairs(util.table.keys(opts[opt])) do
            local list = opts[opt][title]
            local link_subs = {
                uri     = list.uri,
                id      = list.id,
                name    = util.escape(list.uri),
                title   = list.title,
                white   = list.white,
                black   = list.black,
                ignored = list.ignored
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

        local block_subs = {
            opt   = opt,
            links = table.concat(links, "\n")
        }
        local block = string.gsub(block_template, "{(%w+)}", block_subs)
        table.insert(lines, block)
    end

    local rulescount = { black = 0, white = 0, ignored = 0 }
    for _, list in pairs(adblock.rules) do
        if list.black and list.white and list.ignored then
            rulescount.black, rulescount.white, rulescount.ignored = rulescount.black + list.black, rulescount.white + list.white, rulescount.ignored + list.ignored
        end
    end
    -- Display rules count only if have them been count
    local html_rules = ""
    if rulescount.black + rulescount.white + rulescount.ignored > 0 then
        html_rules = string.gsub(rules_template, "{(%w+)}", rulescount)
    end

    local toggle_button_subs = {
        state = adblock.state() == "Disabled" and "true" or "false",
        label = adblock.state() == "Disabled" and "Enable" or "Disable",
    }

    local html_subs = {
        opts   = table.concat(lines, "\n\n"),
        title  = html_page_title,
        style  = chrome.stylesheet .. html_style,
        state = adblock.state(),
        mode  = adblock.mode(),
        rules = html_rules,
        toggle = string.gsub(toggle_button_template, "{(%w+)}", toggle_button_subs),
    }

    local html = string.gsub(html_template, "{(%w+)}", html_subs)
    view:load_string(html, tostring(uri))

    local export_funcs = {
        adblock_toggle = function (enable)
            meta.w:run_cmd(enable and ":adblock-enable" or ":adblock-disable")
        end,
    }

    function on_first_visual(_, status)
        -- Wait for new page to be created
        if status ~= "first-visual" then return end

        -- Hack to run-once
        view:remove_signal("load-status", on_first_visual)

        -- Double check that we are where we should be
        if view.uri ~= meta.uri then return end

        -- Export luakit JS<->Lua API functions
        for name, func in pairs(export_funcs) do
            view:register_function(name, func)
        end
    end

    view:add_signal("load-status", on_first_visual)
end)

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
