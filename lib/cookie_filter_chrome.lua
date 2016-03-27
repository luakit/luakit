local cookie_filter_lib = require("cookie_filter")
local lousy     = lousy
local add_binds, add_cmds = add_binds, add_cmds
local chrome    = chrome
local pairs     = pairs
local ipairs    = ipairs
local string    = string
local table     = table
local window    = window

module("cookie_filter_chrome")

-- Templates
cookie_template = [==[
    <tr>
        <td>{domain}</td>
        <td>{name}</td>
        <td class="value">{value}</td>
        <td class="state_{state}">{state}</td>
        <td>{action}</td>
    </tr>
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
    .state_Allowed {
        color: #799D6A;
        font-weight: bold;
    }
    .state_Blocked {
        color: #CF6A4C;
        font-weight: bold;
    }
    .value {
        font-family: monospace;
    }
    div.tag {
        padding: 0.4em 0.5em;
        margin: 0 0 0.5em;
        clear: both;
    }
    span.id {
        font-size: small;
        color: #333333;
        float: right;
    }
    a.enable, a.disable {
        float: right;
    }
    .tag ul {
        padding: 0;
        margin: 0;
        list-style-type: none;
    }
    .tag li {
        margin: 1em 0;
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
            v.state = allowed and "Allowed" or "Blocked"
            v.action = "<a href=# class=" .. (allowed and "disable" or "enable") .. " onclick='cookie_filter_set(\"".. v.domain .. "\", \"" .. v.name .. "\", " .. (allowed and 0 or 1) .. ")'>" .. (allowed and "Block" or "Allow") .. "</a>"
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
    view:load_string(html, meta.uri)

    local export_funcs = {
        cookie_filter_set = function(domain, name, allow)
            cookie_filter_lib.set(domain, name, allow)
        end
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
