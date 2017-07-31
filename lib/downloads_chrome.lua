--- Downloads for luakit - chrome page.
--
-- This module allows you to monitor the progress of ongoing downloads through a
-- webpage at <luakit://downloads/>.
--
-- @module downloads_chrome
-- @copyright 2010-2012 Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2010 Fabian Streitel <karottenreibe@gmail.com>

-- Grab the luakit environment we need
local downloads = require("downloads")
local lousy = require("lousy")
local chrome = require("chrome")
local modes = require("modes")
local add_binds, add_cmds = modes.add_binds, modes.add_cmds
local webview = require("webview")
local window = require("window")

local _M = {}

local html_template = [==[
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Downloads</title>
    <style type="text/css">
        {style}
    </style>
</head>
<body>
    <header id="page-header">
        <h1>Downloads</h1>
    </header>
    <div id="downloads-list" class="content-margin">
</body>
</html>
]==]

--- CSS for downloads chrome page.
-- @type string
-- @readwrite
_M.stylesheet = [==[
    .download {
        padding-left: 10px;
        position: relative;
        display: block;
        margin: 10px 0 10px 90px;
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
]==]

local main_js = [=[

var months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
    'Oct', 'Nov', 'Dec'];

function basename(url) {
    return url.substring(url.lastIndexOf('/') + 1);
};

function readable_size(bytes, precision) {
    var bytes = bytes || 0, precision = precision || 2,
        kb = 1024, mb = kb*1024, gb = mb*1024, tb = gb*1024;
    if (bytes >= tb) {
        return (bytes / tb).toFixed(precision) + ' TB';
    } else if (bytes >= gb) {
        return (bytes / gb).toFixed(precision) + ' GB';
    } else if (bytes >= mb) {
        return (bytes / mb).toFixed(precision) + ' MB';
    } else if (bytes >= kb) {
        return (bytes / kb).toFixed(precision) + ' KB';
    } else {
        return bytes + ' B';
    }
}

function make_download(d) {
    var e = "<div class='download' id='" + d.id + "' created='" + d.created + "'>";

    var dt = new Date(d.created * 1000);
    e += ("<div class='date'>" + dt.getDate() + " "
        + months[dt.getMonth()] + " " + dt.getFullYear() + "</div>");

    e += ("<div class='details'>"
        + "<div class='title'><a href='file://" + escape(d.destination) + "'>"
        + basename(d.destination) + "</a>"
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

function update_list_finish(downloads) {
    console.log(downloads)
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
        case "started":
            $st.text("downloading - "
                + readable_size(d.current_size) + "/"
                + readable_size(d.total_size) + " @ "
                + readable_size(d.speed) + "/s");
            break;

        case "finished":
            $st.html("Finished - " + readable_size(d.total_size));
            break;

        case "error":
            $st.html("Error");
            break;

        case "cancelled":
            $st.html("Cancelled");
            break;

        case "created":
            $st.html("Waiting");
            break;

        default:
            $st.html("");
            break;
        }
    }
}

function update_list() {
    downloads_get_all(["status", "speed", "current_size", "total_size",
        "destination", "created", "uri",]).then(update_list_finish);
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

local update_list_js = [=[update_list();]=]

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
    if rawget(f, "speed")        then rawset(ret, "speed", data.speed)             end
    return ret
end

local export_funcs = {
    download_get = function (_, id, filter)
        local d, data = downloads.get(id)
        if filter then
            assert(type(filter) == "table", "invalid filter table")
            for _, key in ipairs(filter) do rawset(filter, key, true) end
        end
        return collate_download_data(d, data, filter)
    end,

    downloads_get_all = function (_, filter)
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

    download_show = function (view, id)
        local d = downloads.get(id)
        local dirname = string.gsub(d.destination, "(.*/)(.*)", "%1")
        if downloads.emit_signal("open-file", dirname, "inode/directory") ~= true then
            local w = webview.window(view)
            w:error("Couldn't show download directory (no inode/directory handler)")
        end
    end,

    download_cancel  = function (_, id) return downloads.cancel(id) end,
    download_restart = function (_, id) return downloads.restart(id) end,
    download_open    = function (_, id) return downloads.open(id) end,
    download_remove  = function (_, id) return downloads.remove(id) end,
    downloads_clear  = function (_, id) return downloads.clear(id) end,
}

downloads.add_signal("status-tick", function (running)
    if running == 0 then
        for _, data in pairs(downloads.get_all()) do data.speed = nil end
    end
    for d, data in pairs(downloads.get_all()) do
        if d.status == "started" then
            local last, curr = rawget(data, "last_size") or 0, d.current_size
            rawset(data, "speed", curr - last)
            rawset(data, "last_size", curr)
        end
    end

    -- Update all download pages when a change occurrs
    for _, w in pairs(window.bywidget) do
        for _, v in ipairs(w.tabs.children) do
            if string.match(v.uri or "", "^luakit://downloads/?") then
                v:eval_js(update_list_js, { no_return = true })
            end
        end
    end
end)

chrome.add("downloads", function ()
    local html_subs = {
        style  = chrome.stylesheet .. _M.stylesheet,
    }
    local html = string.gsub(html_template, "{(%w+)}", html_subs)
    return html
end,
function (view)
    -- Load jQuery JavaScript library
    local jquery = lousy.load("lib/jquery.min.js")
    view:eval_js(jquery, { no_return = true })

    -- Load main luakit://download/ JavaScript
    view:eval_js(main_js, { no_return = true })
end,
export_funcs)

--- URI of the downloads chrome page.
-- @type string
-- @readonly
_M.chrome_page = "luakit://downloads/"

add_binds("normal", {
    { "gd", [[Open <luakit://downloads> in current tab.]],
        function (w) w:navigate(_M.chrome_page) end },

    { "gD", [[Open <luakit://downloads> in new tab.]],
        function (w) w:new_tab(_M.chrome_page) end },
})

add_cmds({
    { ":downloads", [[Open <luakit://downloads> in new tab.]],
        function (w) w:new_tab(_M.chrome_page) end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
