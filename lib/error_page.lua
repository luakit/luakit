local assert = assert
local webview = webview
local string = string
local styles = styles
local pairs = pairs
local ipairs = ipairs
local lousy = require "lousy"
local type = type
local setmetatable = setmetatable
local web_module = web_module

module("error_page")

local error_page_wm = web_module("error_page_webmodule")

html_template = [==[
    <html>
        <head>
            <title>Error</title>
            <style type="text/css">
                {style}
            </style>
        </head>
    <body>
        <div id="errorContainer">
            <div id="errorTitle">
                <p id="errorTitleText">{heading}</p>
            </div>
            {content}
            {buttons}
        </div>
    </body>
    </html>
]==]

style = [===[
    body {
        margin: 0;
        padding: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        background: repeating-linear-gradient(
            45deg,
            #ddd,
            #ddd 10px,
            #dadada 10px,
            #dadada 20px
        );
    }

    #errorContainer {
        background: #fff;
        min-width: 35em;
        max-width: 35em;
        padding: 2.5em;
        border: 2px solid #aaa;
        -webkit-border-radius: 5px;
    }

    #errorTitleText {
        font-size: 120%;
        font-weight: bold;
    }

    .errorMessage {
        font-size: 90%;
    }

    #errorMessageText {
        font-size: 80%;
    }

    form, p {
        margin: 0;
    }

    #errorContainer > div:not(:last-of-type) {
        margin-bottom: 1em;
    }

    form {
        margin-top: 1em;
    }
]===]

cert_style = [===[
    body {
        background: repeating-linear-gradient(
            45deg,
            #bf5959,
            #bf5959 10px,
            #b55 10px,
            #b55 20px
        );
    }
    #errorContainer {
        border: 2px solid #666;
    }
]===]

local function false_cb(v, status) return false end
local function true_cb(v, status) return true end

local view_finished = setmetatable({}, { __mode = "k" })

-- Clean up only when error page has finished since sometimes multiple
-- load-status provisional signals are dispatched
local function on_finish(v, status)
    if status ~= "finished" then return end

    -- Start listening for button clicks
    error_page_wm:emit_signal(v, "listen")

    -- Skip the appropriate number of signals
    assert(type(view_finished[v]) == "number")
    view_finished[v] = view_finished[v] - 1
    if view_finished[v] > 0 then return end
    view_finished[v] = nil

    -- Remove userscripts, stylesheet, javascript overrides
    v:remove_signal("enable-styles", false_cb)
    v:remove_signal("enable-scripts", true_cb)
    v:remove_signal("enable-userscripts", false_cb)
    v:remove_signal("load-status", on_finish)
end

local function make_button_html(v, buttons)
    local html = ""
    local tmpl = '<input type="button" class="{class}" value="{label}" />'

    if #buttons == 0 then return "" end

    for i, button in ipairs(buttons) do
        assert(button.label)
        assert(button.callback)
        button.class = button.class or ""
        html = html .. string.gsub(tmpl, "{(%w+)}", button)
    end

    -- Add signals for button messages
    local function error_page_button_cb(_, i)
        buttons[i].callback(v)
    end
    local function error_page_button_cb_cleanup()
        error_page_wm:remove_signal("click", error_page_button_cb)
        v:remove_signal("navigation-request", error_page_button_cb_cleanup)
    end
    error_page_wm:add_signal("click", error_page_button_cb)
    v:add_signal("navigation-request", error_page_button_cb_cleanup)

    return '<form name="bl">' .. html .. '</form>'
end

local function load_error_page(v, error_page_info)
    -- Set default values
    local defaults = {
        heading = "Unable to load page",
        content = [==[
            <div class="errorMessage">
                <p>A problem occurred while loading the URL {uri}</p>
            </div>
            <div class="errorMessage">
                <p id="errorMessageText">{msg}</p>
            </div>
        ]==],
        style = style,
        buttons = {{
            label = "Try again",
            callback = function(v)
                v:reload()
            end
        }},
    }

    if error_page_info.style then
        error_page_info.style = style .. error_page_info.style
    end
    error_page_info = lousy.util.table.join(defaults, error_page_info)
    error_page_info.buttons = make_button_html(v, error_page_info.buttons)

    -- Substitute values recursively
    local html = html_template
    repeat
        html, nsub = string.gsub(html, "{(%w+)}", error_page_info)
    until nsub == 0

    v:add_signal("enable-styles", false_cb)
    v:add_signal("enable-scripts", true_cb)
    v:add_signal("enable-userscripts", false_cb)
    view_finished[v] = v.is_loading and 2 or 1
    v:add_signal("load-status", on_finish)
    v:load_string(html, error_page_info.uri)
end

local function get_cert_error_desc(cert_errors)
    local strings = {
        ["unknown-ca"] = "The signing certificate authority is not known.",
        ["bad-identity"] = "The certificate does not match the expected identity of the site that it was retrieved from.",
        ["not-activated"] = "The certificate's activation time is still in the future.",
        expired = "The certificate has expired.",
        insecure = "The certificate has been revoked.",
        ["generic-error"] = "Error not specified.",
    }

    local msg = ""
    for _, e in ipairs(cert_errors) do
        local emsg = strings[e] or "Unknown error."
        msg = msg .. emsg .. " "
    end

    return msg
end

local function handle_error(v, uri, msg, cert_errors)
    local error_category_lut = {
        ["Load request cancelled"] = "ignore",
        ["Plugin will handle load"] = "ignore",
        ["Frame load was interrupted"] = "ignore",
        ["Unacceptable TLS certificate"] = "security",
        ["Web process crashed"] = "crash",
    }
    local category = error_category_lut[msg] or "generic"

    if category == "ignore" then return end

    local error_page_info
    if category == "generic" then
        error_page_info = {
            msg = msg,
        }
    elseif category == "security" then
        local cert = v.certificate

        error_page_info = {
            msg = msg .. ": " .. get_cert_error_desc(cert_errors),
            style = cert_style,
            heading = "Your connection may be insecure!",
            buttons = {{
                label = "Ignore danger",
                callback = function(v)
                    local host = lousy.uri.parse(v.uri).host
                    v:allow_certificate(host, cert)
                    v:reload()
                end,
            }},
        }
    elseif category == "crash" then
        error_page_info = {
            heading = "Web process crashed",
            content = [==[
                <div class="errorMessage">
                    <p>Reload the page to continue</p>
                </div>
            ]==],
            buttons = {{
                label = "Reload page",
                callback = function(v)
                    v:reload()
                end
            }},
        }
    end
    error_page_info.uri = uri

    load_error_page(v, error_page_info)
end

show_error_page = function(v, error_page_info)
    assert(type(v) == "widget" and v.type == "webview")
    assert(type(error_page_info) == "table")
    if not error_page_info.uri then
        error_page_info.uri = v.uri
    end
    load_error_page(v, error_page_info)
end

webview.init_funcs.error_page_init = function(view, w)
    view:add_signal("load-status", function (v, status, ...)
        if status ~= "failed" then return end
        handle_error(v, ...)
        return true
    end)

    view:add_signal("crashed", function(v, ...)
        handle_error(v, v.uri, "Web process crashed")
    end)
end
