--- View the HTML source code of web pages.
--
-- This module provides support for viewing the source code of web pages. It
-- also provides the `view-source:` URI scheme.
--
-- @module view_source
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local lousy = require("lousy")
local webview = require("webview")
local history = require("history")
local add_binds = require("modes").add_binds

local _M = {}

local view_targets = setmetatable({}, { __mode = "k" })

--- Number of spaces to render tabs with.
-- @type number
-- @default 4
-- @readwrite
_M.tab_size = 4

local wait_for_signal_with_arguments = function (obj, sig, ...)
    assert(type(sig) == "string", "signal name must be a string")
    local required_args = {...}
    local co = assert(coroutine.running(), "must be inside coroutine")
    local function signal_checker(_, ...)
        local args = {...}
        for i in ipairs(required_args) do
            if required_args[i] ~= args[i] then return end
        end
        obj:remove_signal(sig, signal_checker)
        local ok, err = coroutine.resume(co)
        if not ok then
            error(("coroutine error %s:\n%s"):format(err, debug.traceback(co)))
        end
    end
    obj:add_signal(sig, signal_checker)
    coroutine.yield()
end

-- Webview used to load URI source
local loader_view = webview.new("about:blank", { private = true })

local get_source_for_view = function (target_view)
    local source = target_view:get_source()

    local lines = lousy.util.string.split(source, "\r?\n")
    for i, line in ipairs(lines) do
        lines[i] = lousy.util.escape(line)
    end

    local css_vars = ([==[
        <style>
            pre { --line-max-num-chars: {line-max-num-chars}; }
        </style>
    ]==]):gsub("{([%w%-]+)}", {["line-max-num-chars"] = #tostring(#lines) })

    local ret = "<span class=line>" .. table.concat(lines, "</span>\n<span class=line>") .. "</span>"
    return "<pre>" .. ret .."</pre>" .. css_vars
end

local view_source_queue = {}

local load_view_source_uri = function ()
    local v, request = unpack(table.remove(view_source_queue))
    local uri = v.uri:match("view%-source:(.*)$")
    local target_view = view_targets[v]

    if not target_view then
        loader_view.uri = uri
        msg.info("loading in background: %s", uri)
        wait_for_signal_with_arguments(loader_view, "load-status", "finished")
    end

    local source = get_source_for_view(target_view or loader_view)

    -- Construct page
    local style = ([===[
        pre {
            tab-size: %d;
            display: inline-block;
            margin: 0;
            min-width: 100%%;
            box-sizing: border-box;
        }
        html, body {
            margin: 0;
            width: 100%%;
        }
        pre span.line:first-child{
            counter-reset: linecounter;
        }
        span.line {
            counter-increment: linecounter;
        }
        span.line:before {
            background: #f8f8f8;
            content: counter(linecounter);
            -webkit-user-select: none;
            width: calc(var(--line-max-num-chars)*1ch);
            display: inline-block;
            color: #888;
            text-align: right;
            padding: 0.125em 1ch;
            font-size: 0.8em;
        }
        span.lex.tag { color: #a33243; }
        span.lex.element{ color: #844631; }
        span.lex.comment { color: #558817; }
        span.lex.constant { color: #a8660d; }
        span.lex.escape { color: #844631; }
        span.lex.keyword { color: #2239a8; font-weight: bold; }
        span.lex.library { color: #0e7c6b !important; text-decoration: none !important; }
        span.lex.marker { color: #512b1e; background: #fedc56; font-weight: bold; }
        span.lex.number { color: #a8660d; }
        span.lex.operator { color: #2239a8; font-weight: bold; }
        span.lex.preprocessor { color: #a33243; }
        span.lex.prompt { color: #558817; }
        pre a:link, .sourcecode a:visited { color: #272fc2; }
    ]===]):format(_M.tab_size)
    local html = ([==[
        <html>
            <head>
                <style>%s</style>
            </head>
            <body>%s</body>
        </html>
    ]==]):format(style, source)

    request:finish(html)

    if not target_view then
        loader_view.uri = "about:blank"
        wait_for_signal_with_arguments(loader_view, "load-status", "finished")
    end
end

local process_queue_items = function ()
    if view_source_queue.lock then return end
    view_source_queue.lock = true
    while #view_source_queue > 0 do
        load_view_source_uri()
    end
    view_source_queue.lock = false
end

luakit.register_scheme("view-source")
webview.add_signal("init", function (view)
    view:add_signal("scheme-request::view-source", function (v, _, request)
        table.insert(view_source_queue, {v, request})
        local co = coroutine.create(process_queue_items)
        local ok, err = coroutine.resume(co)
        if not ok then
            error(("coroutine error %s:\n%s"):format(err, debug.traceback(co)))
        end
    end)
end)

-- Don't add view-source: entries to history
history.add_signal("add", function (uri)
    if uri:match("^view%-source:") then return false end
end)

add_binds("command", {
    { ":view-source, :vs", "View the source code of the current document.",
        function (w)
            local target = w.view
            local display = w:new_tab(nil, { private = target.private })
            view_targets[display] = target
            display.uri = "view-source:" .. target.uri
        end },
})

add_binds("normal", {
    { "<Shift-Control-U>", "View the source code of the current document.",
        function (w) w:run_cmd("vs") end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
