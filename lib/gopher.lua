--- Add gopher:// scheme support.
--
-- The module adds support for Gopher network with basic rendering.
--
-- @module gopher
-- @author Ygrex <ygrex@ygrex.ru>

local socket_loaded, socket = pcall(require, "socket")
if not socket_loaded then
    msg.error("Failed to load LuaSocket: %s", tostring(socket))
    return
end

local webview = require("webview")

local _M = {}

luakit.register_scheme("gopher")

-- menu entry button's inner HTML representing the type of the item
local function gophertype_to_icon(gophertype)
    -- TODO unicode symbols look different
    return ({
        ["0"] = '🖹', -- text file
        ["1"] = '🗁', -- submenu
        ["4"] = '🗞', -- BinHex-encoded
        ["5"] = '🖫', -- DOS file
        ["7"] = '🔍', -- search
        ["8"] = '🖳', -- telnet
        ["9"] = '🖫', -- binary
        ["d"] = '🖫', -- any document format
        ["g"] = '🖼', -- gif
        ["h"] = '🖄',  -- html
        ["I"] = '🖼', -- image
        ["M"] = '📬', -- mbox
        ["p"] = '🖼', -- image
        ["s"] = '🔉', -- sound
        ["T"] = '🖳', -- telnet
    })[gophertype] or "?"
end

-- parse Gopher menu entry, return its structure
local function parse_gopher_line(line, url)
    local ret = {
        line = line,
        item_type = nil,
        display_string = nil,
        selector = nil,
        host = nil,
        port = nil,
        scheme = nil,
    }
    if not line:match("\t") then
        ret.item_type = "i"
        ret.display_string = line
        return ret
    end
    ret.item_type = line:sub(1, 1)
    local fields = {};
    for chunk in line:sub(2):gmatch("([^\t]*)\t?") do
        fields[#fields + 1] = chunk
    end
    ret.display_string = fields[1] or ""
    ret.selector = fields[2] or ""
    ret.host = fields[3] or url.host
    ret.port = (fields[4] or tostring(url.port)):gsub("[^0-9]", "")
    ret.scheme = "gopher"
    if ret.item_type == "T" or ret.item_type == "8" then
        ret.scheme = "telnet"
    end
    return ret
end

-- evaluate a hyperlink for a gopher menu entry
local function href_source(entry)
    local src = entry.selector:match("^URL:(.+)$")
    if not src then
        if entry.scheme == "telnet" then
            src = ([[telnet://%s:%s/]]):format(entry.host, entry.port)
        else
            src = ([[%s://%s:%s/%s%s]]):format(
                entry.scheme,
                entry.host,
                entry.port,
                entry.item_type,
                luakit.uri_encode(entry.selector, "/")
            )
        end
    end
    return src
end

-- present Gopher menu as an HTML page
-- TODO huge function
local function menu_to_html(data, url)
    -- fix new-line
    if not ({["\r"] = true, ["\n"] = true})[data:sub(-1) or ""] then
        data = data .. "\n"
    end
    local html = {
        "<html>",
        "<head>",
            [[<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
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
        local entry = parse_gopher_line(line, url)
        if entry.item_type == "i" then
            html[#html + 1] = ("<pre>%s</pre>"):format(entry.display_string)
        else
            local src = href_source(entry)
            local frame_name = "iframe_" .. tostring(line_num)
            local iframe = [[<iframe
                style="display:none; width:100%"
                id="]] .. frame_name .. [["></iframe>
            ]]
            local button = ([[<button onclick="showIFrame('%s', '%s')">%s</button>]]):format(
                frame_name,
                src,
                gophertype_to_icon(entry.item_type)
            )
            local anchor_name = "anchor_" .. tostring(line_num)
            local input = [[<br/>
                <input
                    type="text"
                    style="width:100%"
                    onKeyPress="runSearch(this, event, ']] .. anchor_name .. [[')"
                />]]
            if entry.item_type ~= "7" then input = "" end
            html[#html + 1] = ([[<li>%s <a href="%s" id="%s">%s</a>%s</li>]]):format(
                button,
                src,
                anchor_name,
                entry.display_string,
                input
            ) .. iframe
        end
        -- TODO nasty in-place HTML edit
        if html[#html]:sub(1, 5) == "<pre>" and (html[#html - 1] or ""):sub(-6) == "</pre>" then
            html[#html] = html[#html]:sub(6)
            html[#html - 1] = html[#html - 1]:sub(1, -7)
        end
    end
    html[#html + 1] = "</ul></body></html>"
    return table.concat(html, "\n")
end

-- guess the image MIME type by a filename suffix
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

-- convert raw data received from server into the browser's representation
local function data_to_browser(data, url)
    local mime = "text/html"
    local converted = data
    if url.gophertype == "1" or url.gophertype == "7" then
        converted = menu_to_html(data, url)
    elseif url.gophertype == "0" then
        mime = "text/plain"
    elseif url.gophertype == "4" then
        mime = "application/mac-binhex40"
    elseif url.gophertype == "5" then
        mime = "application/octet-stream"
    elseif url.gophertype == "9" then
        mime = "application/octet-stream"
    elseif url.gophertype == "d" then
        mime = "application/octet-stream"
    elseif url.gophertype == "g" then
        mime = "image/gif"
    elseif url.gophertype == "M" then
        mime = "application/mbox"
    elseif url.gophertype == "p" then
        mime = "image/png"
    elseif url.gophertype == "I" then
        mime = image_mime_type(url.selector:lower():match("%.(.-)$"))
    elseif url.gophertype ~= "h" then
        msg.error("Unsupported item type: '%s'", url.gophertype)
        error("Unsupported item type")
    end
    return converted, mime
end

-- parse Gopher URL, return its structure
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
    selector = luakit.uri_decode(selector)
    local search, gopher_plus_string
    if after_selector then
        search, gopher_plus_string = after_selector:match("^(.-)%%09(.*)$")
        if not search then
            search = after_selector
        end
        search = luakit.uri_decode(search)
        if gopher_plus_string then
            gopher_plus_string = luakit.uri_decode(gopher_plus_string)
        end
    end
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

-- establish connection, wait for the socket to become writable
local function _net_establish_connection(host, port)
    local conn = socket.tcp()
    conn:settimeout(0)
    local res, err, _ = conn:connect(host, port)
    if not res then
        if err ~= "timeout" then
            return error(err)
        end
        while true do
            if coroutine.yield() then
                conn:shutdown("both")
                return
            end
            _, res, err = socket.select(nil, {conn}, 0)
            if (res or {})[conn] then
                break
            end
            if err ~= "timeout" then
                return error(err)
            end
        end
    end
    return conn
end

-- non-blocking sending
local function _net_send_message(conn, message)
    local res, err, last
    local sent = 0
    while true do
        res, err, last = conn:send(message, sent + 1)
        if res == #message then
            break
        end
        if not res then
            if err ~= "timeout" then
                return error(err)
            end
        end
        sent = res or last
        if coroutine.yield() then
            conn:shutdown("both")
            return
        end
    end
    return sent
end

-- non-blocking reading
local function _net_read_data(conn)
    local chunks = {}
    while true do
        local res, err, last = conn:receive("*a")
        if err == "closed" then
            res = last
        end
        if res then
            chunks[#chunks + 1] = res
            break
        end
        if err ~= "timeout" then
            return error(err)
        end
        chunks[#chunks + 1] = last
        if coroutine.yield() then
            conn:shutdown("both")
            return
        end
    end
    return table.concat(chunks)
end

-- perform network transaction in non-blocking mode
local function net_request(host, port, message)
    local conn = _net_establish_connection(host, port)
    if not conn then return end
    local sent = _net_send_message(conn, message)
    if not sent then return end
    local data = _net_read_data(conn)
    conn:shutdown("both")
    return data
end

local load_timer = timer{interval = 50}
local loads = {}
load_timer:add_signal("timeout", function ()
    if not next(loads) then load_timer:stop() end
end)

-- remove a background loader
local function remove_loader(v, loader)
    local corou = loads[v]
    if corou then
        loads[v] = nil
        coroutine.resume(corou, "stop")
    end
    if loader then
        load_timer:remove_signal("timeout", loader)
    end
end

webview.add_signal("init", function (view)
    view:add_signal("scheme-request::gopher", function (v, uri, request)
        local url = assert(parse_url(uri))
        local message = table.concat({url.selector, url.search}, "\t")
        local net = coroutine.create(function ()
            return net_request(url.host, url.port, message .. "\r\n")
        end)
        if not load_timer.started then load_timer:start() end
        loads[v] = net
        local function loader ()
            if loads[v] ~= net then
                remove_loader(v, loader)
                return
            end
            local alive, _ = pcall(function() return v.is_loading end)
            local status, res = coroutine.resume(net, not alive)
            if not status then
                if not request.finished then
                    request:finish("Error: " .. tostring(res), "text/plain")
                end
                return remove_loader(v, loader)
            end
            if not res then
                return
            end
            if not request.finished then
                request:finish(data_to_browser(res, url))
            end
            remove_loader(v, loader)
        end
        load_timer:add_signal("timeout", loader)
    end)
    view:add_signal("load-status", function (v, status)
            if status == "failed" then
                remove_loader(v)
            end
    end)
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
