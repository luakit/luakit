local chrome = require "chrome" 
local history = require "history"
local bookmarks = require "bookmarks"
local capi = { luakit = luakit }
local it = require "itertools"

local page    = "chrome://favs/" 
local pattern = page.."?" 

local cutycapt_bin = "/usr/bin/cutycapt"
local cutycapt_opt = "--min-width=1024 --min-height=768" 
local mogrify_bin  = "/usr/bin/mogrify" 
local mogrify_opt  = "-extent 1024x768 -size 240x180 -resize 240x180" 

local html_template = [==[
<html>
<head>
    <title>Speed Dial</title>
    <style type="text/css">
    {style}
    </style>
</head>
<body>
<div id="sidebar">
    <div id="history"><span>History</span><ul> {hist} </ul></div>
    <div id="bookmarks"><span><a href="chrome://bookmarks">Bookmarks</a></span><ul> {bmarks} </ul></div>
</div>
<div id="thumbs"> {favs} </div>
</body>
</html>
]==]

local html_style = [===[
body {
    background: #afafaf;
    margin: 0 5%;
}
div#thumbs {
    text-align: left;
    margin-right: 250px;
}
a.fav {
    background: #e0e0e0;
    display: inline-block;
    width: 260px;
    border: 1px solid black;
    border-radius: 5px;
    padding: 0 0 10px;
    margin: 8px;
    text-align: left;

    text-decoration: none;
    font-size: 12px;
    color: black;
}
a.fav:hover {
    background: #ffffff;
    border-width:1px;
}
a.fav img {
    border: 1px solid #909090;
    width: 240px;
    height: 180px;
    margin: 0 10px;
}
a.fav span {
    background-repeat: no-repeat;
    background-position: 10px center;
    background-color: #f0f0f0;
    color: black;
    display: block;
    padding: 2px 0 2px 29px;
    border-radius: 5px 5px 0 0;
    margin-bottom: 5px;
}
div#sidebar {
    float: right;
    width: 260px;
}
div#sidebar div {
    color: black;
    font-size: 12px;
    text-align: left;
    padding: 0 0 10px 0;
    margin: 8px 5px;
    border: 1px solid black;
    border-radius: 5px;
    height: 20em;
    background: white;
}
div#sidebar ul {
    overflow-y: auto;
    overflow-x: hidden;
    height: 19em;
    margin: 0;
    padding: 0 0 0 30px;
}
div#sidebar li {
    padding: 2px 0px;
}
div#sidebar span {
    font-weight: bold;
    background: #f0f0f0;
    display: block;
    border-radius: 5px 5px 0 0;
    padding: 2px 0 2px 10px;
}
div#sidebar sup {
    white-space: nowrap;
}
]===]

local fav_template = [==[
    <a class="fav" href="{url}">
        <span style="background-image: url({favicon});">{title}</span>
        <img src="{thumb}" />
    </a>
]==]

local function favs()
    local favs = {}
    local updated = {}

    local f = io.open(capi.luakit.data_dir .. "/favs")
    for line in f:lines() do
        local url, thumb, refresh, title = line:match("(%S+)%s+(%S+)%s+(%S+)%s+(.+)")
        if thumb == "none" or refresh == "yes" then
            thumb = string.format("%s/thumbs/thumb-%s.png", capi.luakit.data_dir, url:gsub("%W",""))
            local cmd = string.format('%s %s --url="%s" --out="%s" && %s %s %s', cutycapt_bin, cutycapt_opt, url, thumb, mogrify_bin, mogrify_opt, thumb)
            capi.luakit.spawn(string.format("/bin/sh -c '%s'", cmd))
        end
        updated[#updated+1] = string.format("%s %s %s %s", url, thumb, refresh, title)

        local subs = {
            url   = url,
            thumb = "file://"..thumb,
            title = title,
            favicon = url .. '/favicon.ico',
        }
        favs[#favs+1] = fav_template:gsub("{(%w+)}", subs)
    end
    f:close()

    local f = io.open(capi.luakit.data_dir .. "/favs", "w")
    f:write(table.concat(updated, "\n"))
    f:close()

    return table.concat(favs, "\n")
end

local function hist()
    local template = [==[<li><a href="{uri}">{title}</a> <sup>({time})</sup></li>]==]

    return it.reduce(
        function (acc, v) return acc .. template:gsub("{(%w+)}", { title = v[1], uri = v.uri, time = os.date("%x at %H:%M", v.time) }) end,
            it.unique(it.rvalues(history.hist_list()), function (v) return v.uri end), "")
end

local function bmarks()
    local template = [==[<li><a href="{uri}">{uri}</a> <sup>{tags}</sup></li>]==]
    return it.reduce(
        function (a, v)
            return a .. template:gsub("{(%w+)}", { uri = v.uri, tags = table.concat(v.tags, ", ") })
        end,
        it.limit(it.kvalues(bookmarks.get_data()), 1, 10), "")
end

local function html()
    local subs = {
        style = html_style,
        favs  = favs(),
        hist = hist(),
        bmarks = bmarks(),
    }
    return html_template:gsub("{(%w+)}", subs)
end

local function show(view, w)
    -- the file:// is neccessary so that the thumbnails will be shown.
    -- disables reload though.
    print(w)
    view:load_string(html(), "file://favs")
end

chrome.add(pattern, show)
