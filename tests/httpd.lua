--- Serve a local directory over HTTP
--
-- @script httpd
-- @copyright 2017 Aidan Holm

local socket = require("socket")
local lfs = require("lfs")

-- Options
local ip = "127.0.0.1"
local port = 8888
local backlog = 10

local server = assert(socket.bind(ip, port, backlog))

local function reply_with_not_implemented(client)
    client:send("HTTP/1.0 501 Not Implemented\n\n501 Not Implemented")
end

local function reply_with_dir_contents(client, path)
    local f = io.popen("ls " .. path)
    local contents = f:read("*a") or ""
    f:close()
    client:send("HTTP/1.0 200 OK\n\n" .. "Directory contents:\n\n" .. contents)
end

local function reply_with_file_contents(client, path)
    local f = io.open(path, "rb")
    local contents = f:read("*a") or ""
    f:close()

    local mime = "text/plain"
    if path:match("%.html$") then mime = "text/html" end
    if path:match("%.png$") then mime = "image/png" end
    if path:match("%.jpg$") then mime = "image/jpeg" end

    client:send("HTTP/1.0 200 OK\n")
    client:send(("Content-Length: %d\n"):format(lfs.attributes(path, "size")))
    client:send(("Content-type: %s\n"):format(mime))
    client:send("\n" .. contents)
end

local function reply_with_404(client)
    client:send("HTTP/1.0 404 Not Found\n\n404 Not Found")
end

local function handle_request(client)
    local line = assert(client:receive("*l"))
    local path = line:match("^GET (.*) HTTP/1%.1$")

    if not path then
        reply_with_not_implemented(client)
        return
    end

    path = "tests/html" .. path
    local mode = lfs.attributes(path, "mode")

    if mode == "directory" then
        return reply_with_dir_contents(client, path)
    elseif mode == "file" then
        return reply_with_file_contents(client, path)
    end

    reply_with_404(client)
end

while true do
    local client = assert(server:accept())
    handle_request(client)
    client:close()
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
