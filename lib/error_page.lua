local webview = webview
local string = string
local print = print
local styles = styles
local pairs = pairs

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
                <p id="errorTitleText">Unable to load page</p>
            </div>
            <div class="errorMessage">
                <p>A problem occurred while loading the URL {uri}</p>
            </div>
            <div class="errorMessage">
                <p id="errorMessageText">{msg}</p>
            </div>
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

local function styles(v, status) return false end
local function scripts(v, status) return true end

-- Clean up only when error page has finished since sometimes multiple
-- load-status provisional signals are dispatched
local function cleanup(v, status)
    if status == "finished" then
        v:remove_signal("enable-styles", styles)
        v:remove_signal("enable-scripts", scripts)
    end
end

webview.init_funcs.error_page_init = function(view, w)
    view:add_signal("load-status", function(v, status, uri, msg)
        if status ~= "failed" then return end
        local subs = { uri = uri, msg = msg, style = style }
        local html = string.gsub(html_template, "{(%w+)}", subs)
        v:add_signal("enable-styles", styles)
        v:add_signal("enable-scripts", scripts)
        v:add_signal("load-status", cleanup)
        v:load_string(html, uri)
        return true
    end)
end
