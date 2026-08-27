#!/usr/bin/env luajit

local socket = require("socket")
local lfs = require("lfs")

local port = tonumber(arg[1]) or 0
local doc_root = arg[2] or "tests/html"

local server = assert(socket.bind("0.0.0.0", port))
local _, bound_port = server:getsockname()

-- Print bound port and flush so caller can read it
io.stdout:write(string.format("PORT: %d\n", bound_port))
io.stdout:flush()

local mime_types = {
    html = "text/html; charset=utf-8",
    htm  = "text/html; charset=utf-8",
    txt  = "text/plain; charset=utf-8",
    png  = "image/png",
    jpg  = "image/jpeg",
    jpeg = "image/jpeg",
    css  = "text/css",
    js   = "application/javascript",
}

local function send_response(client, status_code, status_text, content_type, body)
    body = body or ""
    local response = string.format(
        "HTTP/1.0 %d %s\r\n"
        .. "Content-Type: %s\r\n"
        .. "Content-Length: %d\r\n"
        .. "Connection: close\r\n\r\n"
        .. "%s",
        status_code,
        status_text,
        content_type or "text/plain; charset=utf-8",
        #body,
        body
    )
    client:send(response)
end

while true do
    local client = server:accept()
    if client then
        client:settimeout(2.0)
        local request_line, err = client:receive("*l")
        if request_line and not err then
            local method, path = request_line:match("^(%u+)%s+(%S+)")
            if method and path then
                -- Consume headers
                while true do
                    local h = client:receive("*l")
                    if not h or h == "" then break end
                end

                path = path:match("^([^?#]*)")
                if path:find("%.%.") then
                    send_response(client, 403, "Forbidden", "text/plain; charset=utf-8", "403 Forbidden\n")
                else
                    local file_path = doc_root .. path
                    local attr = lfs.attributes(file_path)
                    if attr and attr.mode == "directory" then
                        file_path = file_path:gsub("/?$", "/index.html")
                        attr = lfs.attributes(file_path)
                    end

                    if attr and attr.mode == "file" then
                        local f = io.open(file_path, "rb")
                        if f then
                            local data = f:read("*a") or ""
                            f:close()
                            local ext = file_path:match("%.([%a%d]+)$")
                            local mime = (ext and mime_types[ext:lower()]) or "application/octet-stream"
                            send_response(client, 200, "OK", mime, data)
                        else
                            send_response(
                                client, 500, "Internal Server Error",
                                "text/plain; charset=utf-8", "500 Internal Server Error\n"
                            )
                        end
                    else
                        send_response(client, 404, "Not Found", "text/plain; charset=utf-8", "404 Not Found\n")
                    end
                end
            end
        end
        client:close()
    end
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
