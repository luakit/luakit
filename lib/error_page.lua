local webview = webview
local string = string
local print = print
local styles = styles
local pairs = pairs
local ipairs = ipairs
local util = require "lousy.util"

module("error_page")

html_template = [==[
    <html>
        <head>
            <title>Error</title>
            <style type="text/css">
                {style}
            </style>
            <script type="text/javascript">
                function tryagain() { location.reload(); }
            </script>
        </head>
    <body>
        <div id="errorContainer">
            <div id="errorTitle">
                <p id="errorTitleText">{heading}</p>
            </div>
            {content}
            <form name="bl">
                <input type="button" value="Try again" onclick="javascript:tryagain()" />
            </form>
        </div>
    </body>
    </html>
]==]

style = [===[
    body {
        background-color: #ddd;
        margin: 0;
        padding: 0;
        display: flex;
        align-items: center;
        justify-content: center;
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

    #errorContainer > div {
        margin-bottom: 1em;
    }
]===]

cert_style = style .. [===[
    body {
        background: repeating-linear-gradient(
            45deg,
            #c66,
            #c66 10px,
            #b55 10px,
            #b55 20px
        );
    }
    #errorContainer {
        border: 2px solid #666;
    }
]===]

local function styles(v, status) return false end
local function scripts(v, status) return true end
local function userscripts(v, status) return false end

-- Clean up only when error page has finished since sometimes multiple
-- load-status provisional signals are dispatched
local function cleanup(v, status)
    if status == "finished" then
        v:remove_signal("enable-styles", styles)
        v:remove_signal("enable-scripts", scripts)
        v:remove_signal("enable-userscripts", userscripts)
    end
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
    }
    error_page_info = util.table.join(defaults, error_page_info)

    -- Substitute values recursively
    local html = html_template
    repeat
        html, nsub = string.gsub(html, "{(%w+)}", error_page_info)
    until nsub == 0

    v:add_signal("enable-styles", styles)
    v:add_signal("enable-scripts", scripts)
    v:add_signal("enable-userscripts", userscripts)
    v:add_signal("load-status", cleanup)
    v:load_string(html, v.uri)
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
        error_page_info = {
            msg = msg .. ": " .. get_cert_error_desc(cert_errors),
            style = cert_style,
            heading = "Your connection may be insecure!",
        }
    elseif category == "crash" then
        error_page_info = {
            content = [==[
                <div class="errorMessage">
                    <p>Reload the page to continue</p>
                </div>
            ]==]
        }
    end
    error_page_info.uri = uri

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
