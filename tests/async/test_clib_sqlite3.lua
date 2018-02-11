--- Test sqlite clib functionality.
--
-- @copyright Mason Larobina <mason.larobina@gmail.com>

local assert = require "luassert"

local T = {}

T.test_module = function ()
    assert.is_table(sqlite3)
end

T.test_open_db = function ()
    local db = sqlite3{filename=":memory:"}
    assert.is_equal("sqlite3", type(db))

    -- Should error without constructor table
    assert.has_error(function () sqlite3() end)

    -- Should error without filename in constructor table
    assert.has_error(function () sqlite3{} end)
end

T.test_sqlite3_exec = function ()
    local ret
    local db = sqlite3{filename=":memory:"}
    ret = db:exec([[CREATE TABLE IF NOT EXISTS test (
        id INTEGER PRIMARY KEY,
        uri TEXT,
        created FLOAT
    )]])
    assert.is_nil(ret)

    assert.has_no.errors(function () db:exec(";") end)

    ret = db:exec(";")
    assert.is_nil(ret)

    ret = db:exec([[SELECT * FROM test;]])
    assert.is_table(ret)
    assert.is_equal(0, #ret)

    ret = db:exec([[INSERT INTO test VALUES(NULL, "google.com", 1234.45)]])
    assert.is_nil(ret)

    ret = db:exec([[SELECT * FROM test;]])
    assert.is_table(ret)
    assert.is_equal(1, #ret)

    ret = ret[1]
    assert.is_table(ret)
    assert.is_equal("google.com", ret.uri)
    assert.is_equal(1234.45, ret.created)

    ret = db:exec([[INSERT INTO test VALUES(:id, :uri, :created);]],
        { [":uri"] = "reddit.com", [":created"] = 1000 })

    assert.is_nil(ret)

    ret = db:exec([[SELECT * FROM test;]])
    assert.is_table(ret)
    assert.is_equal(2, #ret)

    ret = ret[2]
    assert.is_table(ret)
    assert.is_equal("reddit.com", ret.uri)
    assert.is_equal(1000, ret.created)

--    for i, row in ipairs(ret) do
--        for k,v in pairs(row) do
--            print("row", i, k, v)
--        end
--    end
end

T.test_compile_statement = function ()
    local db = sqlite3{filename=":memory:"}
    local ret, insert, tail, select_all
    ret, tail = db:exec([[CREATE TABLE IF NOT EXISTS test (
        id INTEGER PRIMARY KEY,
        uri TEXT,
        created FLOAT
    )]])
    assert.is_nil(ret)
    assert.is_nil(tail)

    -- Compile some statements
    insert, tail = db:compile([[INSERT INTO test VALUES(:id, :uri, :created);]])
    assert.is_equal("sqlite3::statement", type(insert))
    assert.is_nil(tail)

    select_all, tail = db:compile([[SELECT * FROM test;]])
    assert.is_equal("sqlite3::statement", type(select_all))
    assert.is_nil(tail)

    ret = insert:exec{ [":uri"] = "google.com", [":created"] = 1000 }
    assert.is_nil(ret)
    ret = insert:exec{ [":uri"] = "reddit.com", [":created"] = 12.34 }
    assert.is_nil(ret)

    ret = select_all:exec()
    assert.is_table(ret)
    assert.is_equal(2, #ret)

    assert.is_table(ret[1])
    assert.is_equal("google.com", ret[1].uri)
    assert.is_equal(1000, ret[1].created)
    assert.is_table(ret[2])
    assert.is_equal("reddit.com", ret[2].uri)
    assert.is_equal(12.34, ret[2].created)

    -- Re-run last statement with same bound values
    ret = insert:exec()
    assert.is_nil(ret)

    ret = select_all:exec()
    assert.is_table(ret)
    assert.is_equal(3, #ret)

    assert.is_table(ret[3])
    assert.is_equal("reddit.com", ret[3].uri)
    assert.is_equal(12.34, ret[3].created)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
