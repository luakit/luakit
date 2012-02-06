----------------------------------------------------------------
-- Bookmark managing                                          --
-- Copyright © 2010 Henning Hasemann <hhasemann@web.de>       --
-- Copyright © 2010 Mason Larobina <mason.larobina@gmail.com> --
----------------------------------------------------------------

-- Grab environment we need
local table = table
local string = string
local io = io
local os = os
local unpack = unpack
local type = type
local pairs = pairs
local ipairs = ipairs
local assert = assert
local capi = { luakit = luakit }
local chrome = require("chrome")
local lousy = require("lousy")
local util = lousy.util
local add_binds, add_cmds = add_binds, add_cmds
local tonumber = tonumber
local tostring = tostring
local window = window

-- Bookmark functions that operate on a flatfile and output to html
module("bookmarks")

-- Loaded bookmarks
local data = {}

-- Some default settings
bookmarks_file = capi.luakit.data_dir .. '/bookmarks'

-- Templates
block_template = [==[<div class="tag"><h1>{tag}</h1><ul>{links}</ul></div>]==]
link_template  = [==[<li><a href="{uri}">{name}</a> <span class="id">{id}</span></li>]==]

html_template = [==[
<html>
<head>
    <title>{title}</title>
    <style type="text/css">
    {style}
    </style>
</head>
<body>
{tags}
</body>
</html>
]==]

-- Template subs
html_page_title = "Bookmarks"

html_style = [===[
    body {
        font-family: monospace;
        margin: 25px;
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
        color: #333333;
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

--- Clear in-memory bookmarks
function clear()
    data = {}
end

--- Save the in-memory bookmarks to flatfile.
-- @param file The destination file or the default location if nil.
function save(file)
    if not file then file = bookmarks_file end

    local lines = {}
    for _, bm in pairs(data) do
        local subs = { uri = bm.uri, tags = table.concat(bm.tags or {}, " "), }
        local line = string.gsub("{uri}\t{tags}", "{(%w+)}", subs)
        table.insert(lines, line)
    end

    -- Write table to disk
    local fh = io.open(file, "w")
    fh:write(table.concat(lines, "\n"))
    io.close(fh)
end

--- Add a bookmark to the in-memory bookmarks table
function add(uri, tags, replace, save_bookmarks)
    assert(uri ~= nil, "bookmark add: no URI given")
    if not tags then tags = {} end

    -- Create tags table from string
    if type(tags) == "string" then tags = util.string.split(tags) end

    if not replace and data[uri] then
        local bm = data[uri]
        -- Merge tags
        for _, tag in ipairs(tags) do
            if not util.table.hasitem(bm, tag) then table.insert(bm, tag) end
        end
    else
        -- Insert new bookmark
        data[uri] = { uri = uri, tags = tags }
    end

    -- Save by default
    if save_bookmarks ~= false then save() end
end

-- Remove a bookmark from the in-memory bookmarks table by index
-- @param index Index of the bookmark to delete
-- @param save_bookmarks Option whether to save the bookmarks to file or not
function del(index, save_bookmarks)
    assert(index ~= nil, "bookdel: Index has to be a number")
    assert(index > 0, "bookdel: Index has to be > 0")

    -- Remove entry from data table
    local id = 0
    for _, bm in pairs(data) do
        id = id + 1
        if id == index then
            data[_] = nil
            break
        end
    end

    -- Save by default
    if save_bookmarks ~= false then save() end

    -- Refresh open bookmarks views
    for _, w in pairs(window.bywidget) do
        for _, v in ipairs(w.tabs.children) do
            if string.match(v.uri, "^luakit://bookmarks/?") then
                v:reload()
            end
        end
    end
end

--- Load bookmarks from a flatfile to memory.
-- @param file The bookmarks file or the default bookmarks location if nil.
-- @param clear_first Should the bookmarks in memory be dumped before loading.
function load(file, clear_first)
    if clear_first then clear() end

    -- Find a bookmarks file
    if not file then file = bookmarks_file end
    if not os.exists(file) then return end

    -- Read lines into bookmarks data table
    for line in io.lines(file or bookmarks_file) do
        local uri, tags = unpack(util.string.split(line, "\t"))
        if uri ~= "" then add(uri, tags, false, false) end
    end
end

--- Shows the chrome page in the given view.
chrome.add("bookmarks/", function (view, uri)
    -- Get a list of all the unique tags in all the bookmarks and build a
    -- relation between a given tag and a list of bookmarks with that tag.
    local tags = {}
    local id = 0
    for _, bm in pairs(data) do
        id = id + 1
        bm['id'] = id
        for _, t in ipairs(bm.tags) do
            if not tags[t] then tags[t] = {} end
            tags[t][bm.uri] = bm
        end
    end

    -- For each tag build
    local lines = {}
    for _, tag in ipairs(util.table.keys(tags)) do
        local links = {}
        for _, uri in ipairs(util.table.keys(tags[tag])) do
            local bm = tags[tag][uri]
            local link_subs = {
                uri = bm.uri,
                id = bm.id,
                name = util.escape(bm.uri),
            }
            local link = string.gsub(link_template, "{(%w+)}", link_subs)
            table.insert(links, link)
        end

        local block_subs = {
            tag   = tag,
            links = table.concat(links, "\n")
        }
        local block = string.gsub(block_template, "{(%w+)}", block_subs)
        table.insert(lines, block)
    end

    local html_subs = {
        tags  = table.concat(lines, "\n\n"),
        title = html_page_title,
        style = html_style
    }

    local html = string.gsub(html_template, "{(%w+)}", html_subs)
    view:load_string(html, tostring(uri))
end)

-- URI of the chrome page
chrome_page    = "luakit://bookmarks/"

-- Add normal binds.
local key, buf = lousy.bind.key, lousy.bind.buf
add_binds("normal", {
    key({}, "B", function (w)
        w:enter_cmd(":bookmark " .. (w.view.uri or "http://") .. " ")
    end),

    buf("^gb$", function (w)
        w:navigate(chrome_page)
    end),

    buf("^gB$", function (w, b, m)
        for i=1, m.count do
            w:new_tab(chrome_page)
        end
    end, {count=1}),
})

-- Add commands.
local cmd = lousy.bind.cmd
add_cmds({
    cmd({"bookmark", "bm"}, function (w, a)
        if not a then
            w:error("Missing bookmark arguments (use `:bookmark <uri> <tags>`)")
            return
        end
        local args = util.string.split(a)
        local uri = table.remove(args, 1)
        add(uri, args)
    end),

    cmd("bookdel", function (w, a)
        del(tonumber(a))
    end),

    cmd("bookmarks", function (w)
        w:navigate(chrome_page)
    end),
})

load()

-- vim: et:sw=4:ts=8:sts=4:tw=80
