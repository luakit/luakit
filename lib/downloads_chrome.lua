-- Grab what we need from the Lua environment
local table = table
local string = string
local io = io
local print = print
local pairs = pairs
local ipairs = ipairs
local math = math
local assert = assert
local setmetatable = setmetatable
local rawget = rawget
local rawset = rawset
local type = type
local os = os

-- Grab the luakit environment we need
local downloads = require("downloads")
local lousy = require("lousy")
local chrome = require("chrome")
local add_binds = add_binds
local add_cmds = add_cmds
local webview = webview
local capi = {
    luakit = luakit
}

module("downloads_chrome")

local function readfile(path)
    local file = assert(io.open(path), "unable to open: " .. path)
    local all = file:read("*a")
    file:close()
    return all
end

local jquery_path, jquery_js = "lib/jquery-1.7.2.min.js"
if capi.luakit.dev_paths then
    if os.exists(jquery_path) then jquery_js = readfile(jquery_path) end
end

if not jquery_js then
    jquery_path = capi.luakit.install_path .. "/" .. jquery_path
    jquery_js = readfile(jquery_path)
end

local html = [==[
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Downloads</title>
    <style type="text/css">
        body {
            background-color: white;
            color: black;
            margin: 10px;
            display: block;
            font-size: 84%;
            font-family: sans-serif;
        }

        div {
            display: block;
        }

        #downloads-summary {
            border-top: 1px solid #888;
            background-color: #ddd;
            padding: 3px;
            font-weight: bold;
            margin-top: 10px;
            margin-bottom: 10px;
        }

        .download {
            -webkit-margin-start: 90px;
            -webkit-padding-start: 10px;
            position: relative;
            display: block;
            margin-bottom: 10px;
        }

        .download .date {
            left: -90px;
            width: 90px;
            position: absolute;
            display: block;
            color: #888;
        }

        .download .title a {
            color: #3F6EC2;
            padding-right: 16px;
        }

        .download .status {
            display: inline;
            color: #999;
            white-space: nowrap;
        }

        .download .uri a {
            color: #56D;
            text-overflow: ellipsis;
            display: inline-block;
            white-space: nowrap;
            text-decoration: none;
            overflow: hidden;
            max-width: 500px;
        }

        .download .controls a {
            color: #777;
            margin-right: 16px;
        }
    </style>
</head>
<body>
    <div id="main">
        <div id="downloads-summary">Downloads</div>
        <div id="downloads-list">
        </div>
    </div>
    <script>
    </script>
</body>
</html>
]==]

local main_js = [=[

var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

function basename(url) {
    return url.substring(url.lastIndexOf('/') + 1);
};

function make_download(d) {
    var e = "<div class='download' id='" + d.id + "' created='" + d.created + "'>";

    var dt = new Date(d.created * 1000);
    e += ("<div class='date'>" + dt.getDate() + " "
        + months[dt.getMonth()] + " " + dt.getFullYear() + "</div>");

    e += ("<div class='details'>"
        + "<div class='title'><a href='file://" + encodeURI(d.destination) + "'>"
        + encodeURI(basename(d.destination)) + "</a>"
        + "<div class='status'>waiting</div></div>"
        + "<div class='uri'><a href='" + encodeURI(d.uri) + "'>"
        + encodeURI(d.uri) + "</a></div></div>");

    e += ("<div class='controls'>"
        + "<a href class='show'>Show in folder</a>"
        + "<a href class='restart'>Retry download</a>"
        + "<a href class='remove'>Remove from list</a>"
        + "<a href class='cancel'>Cancel</a>"
        + "</div>");

    e += "</div>"; // <div class="download">

    return e;
}

function getid(that) {
    return $(that).parents(".download").eq(0).attr("id");
};

function update_list() {
    var downloads = downloads_get_all(["status"]);

    // return if no downloads to display
    if (downloads.length === "undefined") {
        setTimeout(update, 1000); // update 1s from now
        return;
    }

    for (var i = 0; i < downloads.length; i++) {
        var d = downloads[i];
        // find existing element
        var $elem = $("#"+d.id).eq(0);

        // create new download element
        if ($elem.length === 0) {
            // get some more information
            d = download_get(d.id, ["status", "destination", "created", "uri"]);
            var elem_html = make_download(d);

            // ordered insert
            var inserted = false;
            var $all = $("#downloads-list .download");
            for (var j = 0; j < $all.length; j++) {
                if (d.created > $all.eq(j).attr("created")) {
                    $all.eq(j).before(elem_html);
                    inserted = true;
                    break;
                }
            }

            // back of the bus
            if (!inserted) {
                $("#downloads-list").append(elem_html);
            }

            $elem = $("#"+d.id).eq(0);
            $elem.fadeIn();
        }

        // update download controls when download status changes
        if (d.status !== $elem.attr("status")) {
            $elem.find(".controls a").hide();
            switch (d.status) {
            case "created":
            case "started":
                $elem.find(".cancel,.show").fadeIn();
                break;
            case "finished":
                $elem.find(".show,.remove").fadeIn();
                break;
            case "error":
            case "cancelled":
                $elem.find(".remove,.restart").fadeIn();
                break;
            }
            // save latest download status
            $elem.attr("status", d.status);
        }

        // update status text
        var $st = $elem.find(".status").eq(0);
        switch (d.status) {
        case "created":
        case "started":
            $st.html("downloading");
            break;

        case "error":
            $st.html("error!");
            break;

        case "cancelled":
            $st.html("cancelled");
            break;

        case "finished":
        default:
            $st.html("");
            break;
        }
    }

    setTimeout(update_list, 1000);
};

$(document).ready(function () {
    $("#downloads-list").on("click", ".controls .show", function (e) {
        download_show(getid(this));
    });

    $("#downloads-list").on("click", ".controls .restart", function (e) {
        download_restart(getid(this));
    });

    $("#downloads-list").on("click", ".controls .remove", function (e) {
        var id = getid(this);
        download_remove(id);
        elem = $("#"+id);
        elem.fadeOut("fast", function () {
            elem.remove();
        });
    });

    $("#downloads-list").on("click", ".controls .cancel", function (e) {
        download_cancel(getid(this));
    });

    $("#downloads-list").on("click", ".details .title a", function (e) {
        download_open(getid(this));
        return false;
    });

    update_list();
});
]=]

-- default filter
local default_filter = { destination = true, status = true, created = true,
    current_size = true, total_size = true, mime_type = true, uri = true,
    opening = true }

local function collate_download_data(d, data, filter)
    local f = filter or default_filter
    local ret = { id = data.id }
    -- download object properties
    if rawget(f, "destination")  then rawset(ret, "destination", d.destination)    end
    if rawget(f, "status")       then rawset(ret, "status", d.status)              end
    if rawget(f, "uri")          then rawset(ret, "uri", d.uri)                    end
    if rawget(f, "current_size") then rawset(ret, "current_size", d.current_size)  end
    if rawget(f, "total_size")   then rawset(ret, "total_size", d.total_size)      end
    if rawget(f, "mime_type")    then rawset(ret, "mime_type", d.mime_type)        end
    -- data table properties
    if rawget(f, "created")      then rawset(ret, "created", data.created)         end
    if rawget(f, "opening")      then rawset(ret, "opening", not not data.opening) end
    return ret
end

local export_funcs = {
    download_get = function (id, filter)
        local d, data = downloads.get(id)
        if filter then
            assert(type(filter) == "table", "invalid filter table")
            for _, key in ipairs(filter) do rawset(filter, key, true) end
        end
        return collate_download_data(d, data, filter)
    end,

    downloads_get_all = function (filter)
        local ret = {}
        if filter then
            assert(type(filter) == "table", "invalid filter table")
            for _, key in ipairs(filter) do rawset(filter, key, true) end
        end
        for d, data in pairs(downloads.get_all()) do
            table.insert(ret, collate_download_data(d, data, filter))
        end
        return ret
    end,

    download_show = function (id)
        local d, data = downloads.get(id)
        local dirname = string.gsub(d.destination, "(.*/)(.*)", "%1")
        if downloads.emit_signal("open-file", dirname, "inode/directory") ~= true then
            error("Couldn't show download directory (no inode/directory handler)")
        end
    end,

    download_cancel = downloads.cancel,
    download_restart = downloads.restart,
    download_open = downloads.open,
    download_remove = downloads.remove,

    downloads_clear = downloads.clear,
}

function export_functions(view)
    for name, func in pairs(export_funcs) do
        view:register_function(name, func)
    end
end

chrome.add("downloads/", function (view, uri)
    view:load_string(html, "luakit://downloads")
    function on_first_visual(_, status)
        if status == "first-visual" then
            view:remove_signal("load-status", on_first_visual)
            if view.uri == "luakit://downloads" then -- double check
                export_functions(view)
                view:eval_js(jquery_js, { no_return = true })
                local _, err = view:eval_js(main_js, { no_return = true })
                assert(not err, err)
            end
        end
    end
    view:add_signal("load-status", on_first_visual)
end)

local page = "luakit://downloads/"
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^gd$", function (w)
        w:navigate(page)
    end),

    buf("^gD$", function (w)
        w:new_tab(page)
    end),
})

local cmd = lousy.bind.cmd
add_cmds({
    cmd("downloads", function (w)
        w:new_tab(page)
    end),
})
