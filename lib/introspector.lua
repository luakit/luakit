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
local error = error
local package = package
local debug = debug

-- Grab the luakit environment we need
local lousy = require("lousy")
local globals = globals
local dedent = lousy.util.string.dedent
local chrome = require("chrome")
local history = require("history")
local markdown = require("markdown")
local get_modes = get_modes
local get_mode = get_mode
local add_binds = add_binds
local add_cmds = add_cmds
local webview = webview
local capi = {
    luakit = luakit
}

module("introspector")

local html = [==[
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Luakit Introspector</title>
    <style type="text/css">
        body {
            background-color: white;
            color: black;
            display: block;
            font-size: 62.5%;
            font-family: sans-serif;
            width: 700px;
            margin: 1em auto;
        }

        header {
            padding: 0.5em 0 0.5em 0;
            margin: 2em 0 0.5em 0;
            border-bottom: 1px solid #888;
        }

        h1 {
            font-size: 2em;
            font-weight: bold;
            line-height: 1.4em;
            margin: 0;
            padding: 0;
        }

        h3.mode-name {
            color: black;
            font-size: 1.6em;
            margin-bottom: 1.0em;
            line-height: 1.4em;
            border-bottom: 1px solid #888;
        }

        h1, h2, h3, h4 {
            -webkit-user-select: none;
        }

        ol, li {
            margin: 0;
            padding: 0;
            list-style: none;
        }

        pre {
            margin: 0;
            padding: 0;
        }


        .mode {
            width: 100%;
            float: left;
            font-size: 1.2em;
            margin-bottom: 1em;
        }

        .mode .mode-name {
            font-family: monospace, sans-serif;
        }

        .mode .binds {
            clear: both;
            display: block;
        }

        .bind {
            float: left;
            width: 690px;
            padding: 5px;
        }

        .bind:hover {
            background-color: #f8f8f8;
            -webkit-border-radius: 0.5em;
        }

        .bind .link-box {
            float: right;
            font-family: monospace, sans-serif;
            text-decoration: none;
        }

        .bind .link-box a {
            color: #11c;
            text-decoration: none;
        }

        .bind .link-box a:hover {
            color: #11c;
            text-decoration: underline;
        }

        .bind .func-source {
            display: none;
        }

        .bind .key {
            font-family: monospace, sans-serif;
            float: left;
            color: #2E4483;
            font-weight: bold;
        }

        .bind .box {
            float: right;
            width: 550px;
        }

        .bind .desc p:first-child {
            margin-top: 0;
        }

        .bind .desc p:last-child {
            margin-bottom: 0;
        }

        .bind code {
            color: #2525ff;
            display: inline-block;
            font-size: 1.1em;
        }

        .bind pre {
            margin: 1em;
            padding: 0.5em;
            background-color: #EFC;
            border-top: 1px solid #AC9;
            border-bottom: 1px solid #AC9;
        }

        .bind pre code {
            color: #000;
        }

        .mode h4 {
            margin: 1em 0;
            padding: 0;
        }

        .bind .clear {
            display: block;
            width: 100%;
            height: 0;
            margin: 0;
            padding: 0;
            border: none;
        }

        .bind_type_any .key {
            color: #888;
            float: left;
        }

        #templates {
            display: none;
        }
    </style>
</head>
<body>
    <header>
        <h1>Luakit Help</h1>
    </header>

    <div id="templates">
        <div id="mode-section-skelly">
            <section class="mode">
                <h3 class="mode-name"></h3>
                <p class="mode-desc"></p>
                <pre style="display: none;" class="mode-traceback"></pre>
                <ol class="binds">
                </ol>
            </section>
        </div>
        <div id="mode-bind-skelly">
            <ol class="bind">
                <div class="link-box">
                    <a href class="filename"></a>
                    <a href class="linedefined"></a>
                </div>
                <hr class="clear" />
                <div class="key"></div>
                <div class="box desc"></div>
                <div class="box func-source">
                    <h4>Function source:</h4>
                    <pre><code></code></pre>
                </div>
            </ol>
        </div>
    </div>
</body>
]==]

main_js = [=[
$(document).ready(function () {
    var $body = $(document.body);

    var mode_section_html = $("#mode-section-skelly").html(),
        mode_bind_html = $("#mode-bind-skelly").html();

    // Remove all templates
    $("#templates").remove();

    // Get all modes & sub-data
    var modes = help_get_modes();
    for (var i = 0; i < modes.length; i++) {
        var mode = modes[i];
        var $mode = $(mode_section_html);
        $mode.attr("id", "mode-" + mode.name);
        $mode.find("h3.mode-name").text(mode.name + " mode");
        $mode.find("p.mode-desc").html(mode.desc);
        $mode.find("pre.mode-traceback").text(mode.traceback);

        var $binds = $mode.find(".binds");

        var binds = mode.binds;
        for (var j = 0; j < binds.length; j++) {
            var b = binds[j];
            var $bind = $(mode_bind_html);
            $bind.addClass("bind_type_" + b.type);
            $bind.find(".key").text(b.key);
            $bind.find(".func-source code").text(b.func);
            $bind.find(".filename").text(b.filename);

            var $l = $bind.find(".linedefined");
            $l.text("#" + b.linedefined);
            $l.attr("filename", b.filename);
            $l.attr("line", b.linedefined);

            if (b.desc)
                $bind.find(".desc").html(b.desc);
            else
                $bind.find(".clear").hide();

            $binds.append($bind);
        }

        $body.append($mode);
    }

    $body.on("click", ".bind .linedefined", function (event) {
        event.preventDefault();
        var $e = $(this);
        open_editor($e.attr("filename"), $e.attr("line"));
        return false;
    })

    $body.on("click", ".bind .desc a", function (event) {
        event.stopPropagation(); // prevent source toggling
    })

    $body.on("click", ".bind", function (e) {
        var $src = $(this).find(".func-source");
        if ($src.is(":visible"))
            $src.slideUp();
        else
            $src.slideDown();
    })
});
]=]

local function bind_tostring(b)
    local join = lousy.util.table.join
    local t = b.type
    local m = b.mods

    if t == "key" then
        if m or string.wlen(b.key) > 1 then
            return "<".. (m and (m.."-") or "") .. b.key .. ">"
        else
            return b.key
        end
    elseif t == "buffer" then
        local p = b.pattern
        if string.sub(p,1,1) .. string.sub(p, -1, -1) == "^$" then
            return string.sub(p, 2, -2)
        end
        return b.pattern
    elseif t == "button" then
        return "<" .. (m and (m.."-") or "") .. "Mouse" .. b.button .. ">"
    elseif t == "any" then
        return "any"
    elseif t == "command" then
        local cmds = {}
        for i, cmd in ipairs(b.cmds) do
            cmds[i] = ":"..cmd
        end
        return table.concat(cmds, ", ")
    end
end

local source_lines = {}
local function function_source_range(func, info)
    local lines = source_lines[info.source]

    if not lines then
        local source = lousy.load(info.source)
        lines = {}
        string.gsub(source, "([^\n]*)\n", function (line)
            table.insert(lines, line)
        end)
        source_lines[info.source] = lines
    end

    return dedent(table.concat(lines, "\n", info.linedefined,
        info.lastlinedefined), true)
end

export_funcs = {
    help_get_modes = function ()
        local ret = {}
        local modes = lousy.util.table.values(get_modes())
        table.sort(modes, function (a, b) return a.order < b.order end)

        for _, mode in pairs(modes) do
            local binds = {}

            if mode.binds then
                for i, b in pairs(mode.binds) do
                    local info = debug.getinfo(b.func, "uS")
                    info.source = info.source:sub(2)
                    binds[i] = {
                        type = b.type,
                        key = bind_tostring(b),
                        desc = b.desc and markdown(dedent(b.desc)) or nil,
                        filename = info.source,
                        linedefined = info.linedefined,
                        lastlinedefined = info.lastlinedefined,
                        func = function_source_range(b.func, info),
                    }
                end
            end

            table.insert(ret, {
                name = mode.name,
                desc = mode.desc and markdown(dedent(mode.desc)) or nil,
                binds = binds,
                traceback = mode.traceback
            })
        end
        -- Clear source file cache
        source_lines = {}
        return ret
    end,

    open_editor = function (file, line)
        local cmd = string.format("%s -e %s %q +%d", globals.term or "xterm",
            globals.editor or "vim", file, line)
        capi.luakit.spawn(cmd)
    end,
}

chrome.add("help", function (view, meta)
    view:load_string(html, meta.uri)

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

        -- Load jQuery JavaScript library
        local jquery = lousy.load("lib/jquery.min.js")
        local _, err = view:eval_js(jquery, { no_return = true })
        assert(not err, err)

        -- Load main luakit://download/ JavaScript
        local _, err = view:eval_js(main_js, { no_return = true })
        assert(not err, err)
    end

    view:add_signal("load-status", on_first_visual)
end)

local cmd = lousy.bind.cmd
add_cmds({
    cmd("help", "Open [luakit://help/](luakit://help/) in a new tab.",
        function (w) w:new_tab("luakit://help/") end),
})

-- Prevent history items from turning up in history
history.add_signal("add", function (uri)
    if string.match(uri, "^luakit://help/") then return false end
end)
