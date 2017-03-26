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
    test.wait_until(function () return view.source end)

    assert(view.source == contents, "HTTP server returned wrong content for file")
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
