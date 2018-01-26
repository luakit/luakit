--- Add gopher:// scheme support.
--
-- The module adds support for Gopher network with basic rendering.
--
-- @module gopher
-- @author Ygrex <ygrex@ygrex.ru>

local socket = require("socket")
local webview = require("webview")

local _M = {}

luakit.register_scheme("gopher")

local function gophertype_to_icon(gophertype)
    -- TODO unicode symbols look different
    return ({
        ["0"] = '🖹', -- text file
        ["1"] = '🗁', -- submenu
        ["7"] = '🔍', -- search
        ["g"] = '🖼', -- gif
        ["I"] = '🖼', -- image
        ["9"] = '🖫', -- image
        ["p"] = '🖫', -- image
        ["s"] = '🔉', -- sound
        ["T"] = '🖳', -- telnet
        ["h"] = '🖄',  -- html
    })[gophertype] or "?"
end

-- TODO huge function
local function menu_to_html(data, url)
    -- fix new-line
    if not ({["\r"] = true, ["\n"] = true})[data:sub(-1) or ""] then
        data = data .. "\n"
    end
    local html = {
        "<html>",
        "<head>",
            [[<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />]],
            -- TODO injected string should be encoded
            "<title>" .. url.host .. "/" .. url.selector .. "</title>",
            [[
            <script type="text/javascript">
                function showIFrame(iframe_id, source) {
                    var iframe = document.getElementById(iframe_id);
                    iframe.src = source;
                    iframe.style.display = "block";
                }
                function runSearch(input, event, anchor_id) {
                    event = event || window.event;
                    if (event.keyCode != 13)
                        return true;
                    var anchor = document.getElementById(anchor_id);
                    window.location = anchor.href + '%09' + input.value;
                    return false;
                }
            </script>
            ]],
        "</head>",
        "<body><ul>"
    };
    local line_num = 0
    for line in data:gmatch("(.-)\n\r?") do
        line_num = line_num + 1
        if not line:match("\t") then
            html[#html + 1] = ("<pre>%s</pre>"):format(line)
        else
            local item_type = line:sub(1, 1)
            if item_type == "i" then
                html[#html + 1] = ("<pre>%s</pre>"):format(line:sub(2):match("(.-)\t"))
            else
                local fields = {};
                for chunk in line:sub(2):gmatch("([^\t]*)\t?") do
                    fields[#fields + 1] = chunk
                end
                local display_string = fields[1] or ""
                local selector = fields[2] or ""
                local host = fields[3] or url.host
                local port = (fields[4] or tostring(url.port)):gsub("[^0-9]", "")
                -- TODO injected string should be escaped
                local src = ([[gopher://%s:%s/%s%s]]):format(
                    host,
                    port,
                    item_type,
                    selector
                )
                local frame_name = "iframe_" .. tostring(line_num)
                local iframe = [[<iframe
                    style="display:none; width:100%"
                    id="]] .. frame_name .. [["></iframe>
                ]]
                local button = ([[<button onclick="showIFrame('%s', '%s')">%s</button>]]):format(
                    frame_name,
                    src,
                    gophertype_to_icon(item_type)
                )
                local anchor_name = "anchor_" .. tostring(line_num)
                local input = [[<br/>
                    <input
                        type="text"
                        style="width:100%"
                        onKeyPress="runSearch(this, event, ']] .. anchor_name .. [[')"
                    />]]
                if item_type ~= "7" then input = "" end
                html[#html + 1] = ([[<li>%s <a href="%s" id="%s">%s</a>%s</li>]]):format(
                    button,
                    src,
                    anchor_name,
                    display_string,
                    input
                ) .. iframe
            end
            -- TODO nasty in-place HTML edit
            if html[#html]:sub(1, 5) == "<pre>" and (html[#html - 1] or ""):sub(-6) == "</pre>" then
                html[#html] = html[#html]:sub(6)
                html[#html - 1] = html[#html - 1]:sub(1, -7)
            end
        end
    end
    html[#html + 1] = "</ul></body></html>"
    return table.concat(html, "\n")
end

local function image_mime_type(ext)
    return ({
        gif = "image/gif",
        jpeg = "image/jpeg",
        jpg = "image/jpeg",
        pcx = "image/pcx",
        png = "image/png",
        svg = "image/svg+xml",
        svgz = "image/svg+xml",
        tif = "image/tiff",
        tiff = "image/tiff",
        bmp = "image/x-ms-bmp",
        pbm = "image/x-portable-bitmap",
        pgm = "image/x-portable-graymap",
        ppm = "image/x-portable-pixmap",
        xwd = "image/x-xwindowdump",
    })[tostring(ext)] or "application/octet-stream"
end

do
    assert("image/gif" == image_mime_type("gif"))
    assert("image/jpeg" == image_mime_type("jpg"))
    assert("image/svg+xml" == image_mime_type("svg"))
    assert("application/octet-stream" == image_mime_type())
end

local function data_to_browser(data, url)
    local mime = "text/html"
    local converted = data
    if url.gophertype == "1" or url.gophertype == "7" then
        converted = menu_to_html(data, url)
    elseif url.gophertype == "0" then
        mime = "text/plain"
    elseif url.gophertype == "9" then
        mime = "application/octet-stream"
    elseif url.gophertype == "g" then
        mime = "image/gif"
    elseif url.gophertype == "p" then
        mime = "image/png"
    elseif url.gophertype == "I" then
        mime = image_mime_type(url.selector:lower():match("%.(.-)$"))
    elseif url.gophertype ~= "h" then
        print("Unsupported item type: '" .. url.gophertype .. "'")
        error("Unsupported item type")
    end
    return converted, mime
end

local function parse_url(url)
    local host_port, gopher_path = url:match("gopher://([^/]+)/?(.-)$")
    if not host_port then return end
    local host = host_port
    local port = host_port:match(":([0-9]+)$")
    if port then
        host = host_port:match("^(.+):[0-9]+$")
        port = tonumber(port)
    else
        port = 70
    end
    local gophertype = gopher_path:sub(1, 1)
    if not gophertype or #gophertype < 1 then
        gophertype = "1"
    end
    local selector, after_selector = gopher_path:sub(2):match("^(.-)%%09(.*)$")
    if not selector then
        selector = gopher_path:sub(2)
    end
    local search, gopher_plus_string
    if after_selector then
        search, gopher_plus_string = after_selector:match("^(.-)%%09(.*)$")
        if not search then
            search = after_selector
        end
    end
    -- TODO chunks should be decoded
    return {
        host = host,
        port = port,
        gopher_path = gopher_path,
        gophertype = gophertype,
        selector = selector,
        search = search,
        gopher_plus_string = gopher_plus_string,
    }
end

do
    local url
    url = parse_url("gopher://ygrex.ru:80/0/file.txt%09please/search%09plus/command")
    assert(url.host == "ygrex.ru")
    assert(url.port == 80)
    assert(url.gophertype == "0")
    assert(url.selector == "/file.txt")
    assert(url.search == "please/search")
    assert(url.gopher_plus_string == "plus/command")
    url = parse_url("gopher://ygrex.ru")
    assert(url.host == "ygrex.ru")
    assert(url.port == 70)
    assert(url.gophertype == "1")
    assert(url.selector == "")
    assert(url.search == nil)
    assert(url.gopher_plus_string == nil)
end

webview.add_signal("init", function(view)
    view:add_signal("scheme-request::gopher", function(_, uri, request)
        -- Match "gopher://"
        local url = assert(parse_url(uri))
        local s = assert(socket.connect(url.host, url.port))
        local msg = table.concat({url.selector, url.search}, "\t")
        -- TODO should retry if partially sent
        assert(s:send(msg .. "\r\n"))
        -- TODO should have upper limit
        local data = assert(s:receive("*a"))
        s:shutdown("both")
        if not request.finished then
            request:finish(data_to_browser(data, url))
        end
        return
    end)
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
