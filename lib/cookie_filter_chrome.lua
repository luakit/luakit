local cookie_filter_lib = require("cookie_filter")
local lousy     = lousy
local add_binds, add_cmds = add_binds, add_cmds
local chrome    = chrome
local pairs     = pairs
local ipairs    = ipairs
local string    = string
local table     = table
local window    = require("window")

module("cookie_filter_chrome")

-- Templates
cookie_template = [==[
    <tr>
        <td>{domain}</td>
        <td>{name}</td>
        <td>{value}</td>
        <td class="state_{state}">{state}</td>
        <td>{action}</td>
    </tr>
]==]

action_link_template = "<a href=# onclick=\"cookie_filter_set('{domain}', '{name}', {allowed})\">{label}</a>"

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
            <h1>Cookie Filter</h1>
            <span>Domain: {domain}</span>
        </header>
        <div class="content-margin">
            <table>
                <thead>
                    <tr>
                        <th>Domain</th>
                        <th>Name</th>
                        <th>Value</th>
                        <th>State</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    {cookies}
                </tbody>
            </table>
        </div>
    </body>
    </html>
]==]

-- Template subs
html_page_title = "Cookie Filter"

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
    th:not(:nth-child(3)),
    td:not(:nth-child(3)) {
        width: 1px;
    }
    th:nth-child(3),
    td:nth-child(3) {
        overflow: hidden;
        text-overflow: ellipsis;
        max-width: 100px;
        width: 100%;
    }
    td + td, th + th {
        padding-left: 1em;
    }
    header > span {
        padding: 1em 1em 1em 1em;
    }
    /* Colours for cookie filtering states */
    .state_Allowed {
        color: #799D6A;
    }
    .state_Blocked {
        color: #CF6A4C;
    }
    .state_Session {
        color: #FFB964;
    }
    /* Column alignment and text styling */
    td:nth-child(3) {
        font-family: monospace;
    }
    td:nth-child(4) {
        font-weight: bold;
    }
    th:last-child, td:last-child {
        text-align: right;
    }
]===]


-- Functions
-- Refresh open filters views (if any)
function refresh_views()
    for _, w in pairs(window.bywidget) do
        for _, v in ipairs(w.tabs.children) do
            if string.match(v.uri, "^luakit://cookie%-filter/.*") then
                v:reload()
            end
        end
    end
end

cookie_filter_lib.refresh_views = refresh_views

-- URI of the chrome page
chrome_page = "luakit://cookie-filter/"

-- From a given domain, builds an array of that domain and all higher level
-- domains
local function build_domain_set(domain)
    -- Build list of domains
    local domains = {}
    do
        local d = domain
        while d do
            domains[#domains+1] = d
            d = string.match(d, "%.(.+)")
        end
    end

    -- Preprend a . on the domain names if not there already
    for i=1, #domains do
        local d = domains[i]
        if string.sub(d, 1, 1) ~= "." then
            d = "." .. d
            domains[#domains + 1] = d
        end
    end

    return domains
end

--- Shows the chrome page in the given view.
chrome.add("cookie-filter", function (view, meta)
    local domain = meta.path
    -- Strip off trailing # if it exists
    if string.sub(domain, string.len(domain)) == "#" then
        domain = string.sub(domain, 1, string.len(domain)-1)
    end
    local domains = build_domain_set(domain)

    -- build table of cookies on these domains
    local cookies = {}
    for _, d in ipairs(domains) do
        c_for_d = cookie_filter_lib.cookies[d] or {}
        for _, v in pairs(c_for_d) do
            local allowed = cookie_filter_lib.get(d, v.name)

            -- Label for current state
            local states = {
                [cookie_filter_lib.CF_BLOCK] = "Blocked",
                [cookie_filter_lib.CF_ALLOW] = "Allowed",
                [cookie_filter_lib.CF_SESSION_ONLY] = "Session"
            }
            v.state = states[allowed]

            -- List of possible actions
            local actions = {
                [cookie_filter_lib.CF_BLOCK] = "Block",
                [cookie_filter_lib.CF_ALLOW] = "Allow",
                [cookie_filter_lib.CF_SESSION_ONLY] = "Session"
            }
            actions[allowed] = nil

            -- Build html for action links
            local action_links = {}
            for kk, vv in pairs(actions) do
                local subs = { domain = v.domain, name = v.name, allowed = kk, label = vv }
                action_links[#action_links+1] = string.gsub(action_link_template, "{(%w+)}", subs)
            end
            v.action = table.concat(action_links, " ")

            cookies[#cookies+1] = string.gsub(cookie_template, "{(%w+)}", v)
        end
    end

    local html_subs = {
        title  = html_page_title,
        style  = chrome.stylesheet .. html_style,
        domain = domain,
        cookies = table.concat(cookies, ""),
    }

    local html = string.gsub(html_template, "{(%w+)}", html_subs)
    return html
end,
nil,
{
    cookie_filter_set = function(view, domain, name, allow)
        cookie_filter_lib.set(domain, name, allow)
    end
})

local function domain_from_uri(uri)
    local domain = (uri and string.match(string.lower(uri), "^%a+://([^/]*)/?"))
    -- Strip leading www. www2. etc
    domain = string.match(domain or "", "^www%d?%.(.+)") or domain
    return domain or ""
end

local function chrome_page_for_uri(uri)
    local domain = domain_from_uri(uri)
    return chrome_page .. domain
end

-- Add chrome binds.
local key, buf = lousy.bind.key, lousy.bind.buf
add_binds("normal", {
    buf("^gc$", function (w)
        w:navigate(chrome_page_for_uri(w.view.uri))
    end),

    buf("^gC$", function (w, b, m)
        for i=1, m.count do
            w:new_tab(chrome_page_for_uri(w.view.uri))
        end
    end, {count=1}),
})

-- Add chrome commands.
local cmd = lousy.bind.cmd
add_cmds({
    cmd("cookie-filter", function (w)
        w:navigate(chrome_page_for_uri(w.view.uri))
    end),
})
