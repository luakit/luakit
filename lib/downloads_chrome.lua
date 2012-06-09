local downloads = require("downloads")
local lousy = require("lousy")
local chrome = require("chrome")
local add_binds = add_binds
local add_cmds = add_cmds
local table = table
local string = string
local io = io
local print = print
local pairs = pairs
local ipairs = ipairs
local webview = webview
local math = math
local assert = assert

module("downloads_chrome")

local jquery_path, jquery_js = "lib/jquery-1.7.2.min.js"
do
    local file = io.open(jquery_path)
    jquery_js = file:read("*a")
    file:close()
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

        #download-list {
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

        .hover {
            background-color: #eee;
        }
    </style>
</head>
<body>
    <div id="main">
        <div id="downloads-summary">
            Downloads
        </div>
        <div id="download-list">
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

function make_download_elem(d) {
    var e = "<div class='download' id='" + d.id + "'>";

    var dt = new Date(d.created * 1000);
    e += ("<div class='date'>" + dt.getDate() + " "
        + months[dt.getMonth()] + " " + dt.getFullYear() + "</div>");

    e += ("<div class='details'>"
        + "<div class='title'><a href='file://" + encodeURI(d.dest) + "'>"
        + encodeURI(basename(d.dest)) + "</a>"
        + "<div class='status'></div></div>"
        + "<div class='uri'><a href='" + encodeURI(d.uri) + "'>"
        + encodeURI(d.uri) + "</a></div></div>");

    e += ("<div class='controls'>"
        + "<a class='show'    href='#'>Show in folder</a>"
        + "<a class='restart' href='#'>Retry download</a>"
        + "<a class='remove'  href='#'>Remove from list</a>"
        + "<a class='cancel'  href='#'>Cancel</a>"
        + "</div>");

    e += "<div class='graph' style='display: none;'>Some graph here lol</div>";

    e += "</div>"; // <div class="download">

    return e;
}

function getid(that) {
    return $(that).parents(".download").eq(0).attr("id");
};

function update() {
    var downloads = downloads_get_all();
    var ids = [];

    // Check for empty downloads list
    if (downloads.length !== "undefined") {
        for (var i = 0; i < downloads.length; i++) {
            var d = downloads[i];
            var elem = $("#"+d.id);

            // is this a new download?
            if (elem.length === 0) {
                $("#download-list").prepend(make_download_elem(d));
                elem = $("#"+d.id);
                elem.fadeIn();
            }

            if (d.status !== $(elem).attr("status")) {
                // hide all download controls
                $(elem).find(".controls a").hide();
                // now display only the relevant download controls
                switch (d.status) {
                    case "created":
                    case "started":
                        $(elem).find(".cancel,.show").fadeIn();
                        break;
                    case "finished":
                        $(elem).find(".show,.remove").fadeIn();
                        break;
                    case "error":
                    case "cancelled":
                        $(elem).find(".remove,.restart").fadeIn();
                        break;
                    default:
                        break;
                }
                // save latest download status
                $(elem).attr("status", d.status);
            };
        }
    }
    setTimeout(update, 1000) // update 1s from now
};

$(document).ready(function () {
    $("#download-list").on("click", ".controls .show", function (e) {
        downloads_show(getid(this));
    });

    $("#download-list").on("click", ".controls .restart", function (e) {
        downloads_restart(getid(this));
    });

    $("#download-list").on("click", ".controls .remove", function (e) {
        downloads_remove(getid(this));
    });

    $("#download-list").on("click", ".controls .cancel", function (e) {
        downloads_cancel(getid(this));
    });

    update();
});
]=]

local export_funcs = {
    downloads_get_all = function ()
        local ret = {}
        for d, data in pairs(downloads.get_all()) do
            table.insert(ret, {
                id = data.id,
                dest = d.destination,
                status = d.status,
                created = data.created,
                mime = d.mime_type,
                uri = d.uri,
                opening = not not data.opening,
            })
        end
        return ret
    end,

    downloads_show = function (id)
        local d, data = downloads.get(id)
        local dest = string.gsub(d.destination, "(.*/)(.*)", "%1")
        if downloads.emit_signal("open-file", dest, "inode/directory") ~= true then
            error("Couldn't open directory (no handler)")
        end
    end,

    downloads_cancel = downloads.cancel,
    downloads_restart = downloads.restart,
    downloads_open = downloads.open,
    downloads_clear = downloads.clear,
    downloads_remove = downloads.remove,
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
            if view.uri == "luakit://downloads" then -- double check
                export_functions(view)
                view:eval_js(jquery_js, { no_return = true })
                local _, err = view:eval_js(main_js, { no_return = true })
                assert(not err, err)
            end
            view:remove_signal("load-status", on_first_visual)
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
