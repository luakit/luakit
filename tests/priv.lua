--- Utilities for use in tests.
--
-- @module tests.util
-- @copyright 2017 Aidan Holm

local posix = require('posix')

local M = {}

function M.spawn(args)
    assert(type(args) == "table" and #args > 0)

    local child = posix.fork()
    if child == 0 then
        local _, err = posix.execx(args)
        print("execx:", err)
        os.exit(0)
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
