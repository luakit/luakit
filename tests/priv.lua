--- Utilities for use in tests.
--
-- @module tests.util
-- @copyright 2017 Aidan Holm

local posix = require('posix')

local M = {}

function M.spawn(args)
    assert(type(args) == "table" and #args > 0)

    local r, w = posix.pipe()
    local child = posix.fork()

    if child == 0 then
        -- Set up error message pipe
        posix.close(r)
        -- Not future proof, but allows use of regular Lua
        -- Works because CLOEXEC is currently the only FD flag
        posix.fcntl (w, posix.F_SETFD, posix.FD_CLOEXEC)
        -- Exec the new program
        local exe = table.remove(args, 1)
        local _, err = posix.execp(exe, args)
        -- Write error message on failure
        posix.write(w, err)
        posix._exit(0)
    else
        posix.close(w)

        -- Collect any error message
        local err = ""
        repeat
            local part = posix.read(r, 1024)
            err = err .. part
        until #part == 0
        posix.close(r)

        -- Raise error if present
        if #err > 0 then
            err = string.format("failed to spawn '%s': %s", table.concat(args, " "), err)
            error(err)
        end
    end

    return child
end

function M.load_test_file(test_file)
    local ok, ret = pcall(dofile, test_file)
    if not ok then
        return nil, ret
    end
    assert(type(ret) == "table")

    for test_name, func in pairs(ret) do
        assert(type(test_name) == "string")
        assert(type(func) == "function" or type(func) == "thread")
    end

    return ret
end

return M

-- vim: et:sw=4:ts=8:sts=4:tw=80
