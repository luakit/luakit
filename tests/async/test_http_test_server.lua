--- Tests the http test server.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

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

    -- Wrap view.source get in another coroutine, since auto-suspending the
    -- test coroutine confuses the test runner
    coroutine.wrap(function ()
        test.continue(view:get_source())
    end)()
    local source = test.wait()

    assert(source == contents, "HTTP server returned wrong content for file")
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
