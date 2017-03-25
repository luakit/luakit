--- Tests the http test server.
--
-- @copyright Aidan Holm 2017

local T = {}
local test = require "tests.lib"


T.test_http_server_returns_file_contents = function ()
    -- Read file contents
    local f = assert(io.open("tests/html/hello_world.html", "rb"))
    local contents = f:read("*a") or ""
    f:close()

    -- Load URI and wait for completion
    local view = widget{type="webview"}
    view.uri = test.http_server() .. "hello_world.html"
    test.wait_for_view(view)

    -- view.source isn't immediately available... wait a few msec
    local t = timer{interval = 1}
    t:start()
    repeat
        test.wait_for_signal(t, "timeout")
    until view.source

    assert(view.source == contents, "HTTP server returned wrong content for file")
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
