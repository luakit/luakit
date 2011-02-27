local downloads = require("downloads")
local lousy = require("lousy")
local table = table
local add_binds = add_binds
local ipairs = ipairs
local pairs = pairs
local string = string
local window = window
local chrome = require("chrome")
local tostring = tostring
local capi = { timer = timer }

module("downloads.chrome")

local pattern = "^luakit://downloads/?"

--- Template for a download.
download_template = [==[
<div class="download {status}"><h1>{id} {name}</h1>
<span class="modeline">{modeline}</span>&nbsp;&nbsp;
<a class="cancel" href="javascript:cancel_{id}()">Cancel</a>
<a class="delete" href="javascript:delete_{id}()">Delete</a>
<a class="restart" href="javascript:restart_{id}()">Restart</a>
<a class="open" id="open_{id}" href="javascript:open_{id}()">Open</a>
<span class="opening" id="opening_{id}" href="javascript:open_{id}()">Opening...</span>
</div>
]==]

download_js_template = [=[
    if ({opening}) {
        document.getElementById("open_{id}").style.display = "none";
    } else {
        document.getElementById("opening_{id}").style.display = "none";
    }
]=]

--- Template for the HTML page.
html_template = [==[
<html>
<head>
    <title>Downloads</title>
    <style type="text/css">
    {style}
    </style>
</head>
<body>
<div class="header">
<a href="javascript:clear()">Clear all stopped downloads</a>
</div>
<div id="downloads">
{downloads}
</div>
<script>
{script}
</script>
</body>
</html>
]==]

--- CSS styles for the HTML page.
html_style = [===[
    body {
        font-family: monospace;
        margin: 25px;
        line-height: 1.5em;
        font-size: 12pt;
    }
    div.download {
        width: 100%;
        padding: 0px;
        margin: 0 0 25px 0;
        clear: both;
    }
    .download.cancelled {
        background-color: #ffffff;
    }
    .download.error {
        background-color: #ffa07a;
    }
    .download.created {
        background-color: #ffffff;
    }
    .download.started {
        background-color: #ffffff;
    }
    .download.finished {
        background-color: #90ee90;
    }
    .download h1 {
        font-size: 12pt;
        font-weight: bold;
        font-style: normal;
        font-variant: small-caps;
        padding: 0 0 5px 0;
        margin: 0;
        color: #333333;
        border-bottom: 1px solid #aaa;
    }
    .download a, .download span.opening {
        margin-left: 10px;
        float: right;
    }
    .download a:link {
        color: #0077bb;
        text-decoration: none;
    }
    .download a:hover {
        color: #0077bb;
        text-decoration: underline;
    }
    .download.created   a.delete,
    .download.started   a.delete,
    .download.finished  a.cancel,
    .download.error     a.cancel,
    .download.cancelled a.cancel,
    .download.cancelled a.open,
    .download.error     a.open {
        display:none
    }
]===]

-- Compiles the HTML for the downlods, but not the HTML structure around them.
-- Used to refresh the page
local function inner_html()
    local rows = {}
    local js = {}
    for i,d in ipairs(downloads.downloads) do
        local modeline
        if d.status == "started" then
            modeline = string.format("%.2f/%.2f Mb (%i%%) at %.1f Kb/s", d.current_size/1048576,
                d.total_size/1048576, (d.progress * 100), downloads.get_speed(d) / 1024)
        else
            modeline = string.format("%.2f/%.2f Mb (%i%%)", d.current_size/1048576,
                d.total_size/1048576, (d.progress * 100))
        end
        local subs = {
            id       = i,
            name     = downloads.get_basename(d),
            status   = d.status,
            modeline = modeline,
        }
        local row = string.gsub(download_template, "{(%w+)}", subs)
        table.insert(rows, row)

        subs = {
            id       = i,
            opening  = downloads.opening[d] and "true" or "false"
        }
        row = string.gsub(download_js_template, "{(%w+)}", subs)
        table.insert(js, row)
    end
    return table.concat(rows, "\n"), table.concat(js, "\n")
end

--- Compiles the HTML for the download page.
-- @return The HTML to render.
function html()
    local inner_html, inner_js = inner_html()
    local html_subs = {
        style = html_style,
        downloads = inner_html,
        script = inner_js,
    }
    return string.gsub(html_template, "{(%w+)}", html_subs)
end

-- Refreshes all download views.
local refresh_timer = capi.timer{interval=1000}
refresh_timer:add_signal("timeout", function ()
    local continue = false
    -- refresh views
    for _, w in pairs(window.bywidget) do
        local view = w:get_current()
        if string.match(view.uri, pattern) then
            local inner_html, inner_js = inner_html()
            view:eval_js(string.format('document.getElementById("downloads").innerHTML = %q', inner_html), "downloads.lua")
            view:eval_js(inner_js, "downloads.lua")
            continue = true
        end
    end
    -- stop timer if no view was refreshed
    if not continue then refresh_timer:stop() end
end)

--- Shows the chrome page in the given view.
-- @param view The view to show the page in.
chrome.add("downloads/", function (view, uri)
    view:load_string(html(), tostring(uri))
    -- small hack to achieve a one time signal
    local sig = {}
    sig.fun = function (v, status)
        view:remove_signal("load-status", sig.fun)
        if status ~= "committed" or not string.match(view.uri, pattern) then return end
        view:register_function("clear", downloads.clear)
        for i = 1, #(downloads.downloads) do
            for k, v in pairs({
                ["cancel_" ..i] = function() downloads.cancel(i)  end,
                ["open_"   ..i] = function() downloads.open(i)    end,
                ["restart_"..i] = function() downloads.restart(i) end,
                ["delete_" ..i] = function() downloads.delete(i)  end,
            }) do
                view:register_function(k, v)
            end
        end
    end
    view:add_signal("load-status", sig.fun)
    if not refresh_timer.started then refresh_timer:start() end
end)

-- Chrome buffer binds.
local page = "luakit://downloads"
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^gd$", function (w)
        w:navigate(page)
    end),

    buf("^gD$", function (w, b, m)
        for i=1,m.count do w:new_tab(page) end
    end, {count=1}),
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
