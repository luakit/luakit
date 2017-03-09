--- Testing interface.
--
-- @module tests.lib
-- @copyright 2017 Aidan Holm

local _M = {}

local shared_lib = nil

function _M.init(arg)
    _M.init = nil
    shared_lib = arg
end

function _M.fail(msg)
    error(msg, 0)
end

function _M.wait_for_signal(object, signal, timeout)
    assert(shared_lib.current_coroutine, "Not currently running in a test coroutine!")
    assert(coroutine.running() == shared_lib.current_coroutine, "Not currently running in the test coroutine!")
    assert(type(signal) == "string", "Expected string")
    assert(type(timeout) == "number", "Expected number")

    return coroutine.yield({object, signal, timeout=timeout})
end

function _M.http_server()
    return "http://127.0.0.1:8888/"
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
