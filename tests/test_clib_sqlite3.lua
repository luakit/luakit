require "lunit"
module("test_clib_sqlite3", lunit.testcase, package.seeall)

function test_module()
    assert_table(sqlite3)
end

function test_open_db()
    local db = sqlite3{filename=":memory:"}
    assert_equal("sqlite3", type(db))

    assert_error("Should error without constructor table",
        function () sqlite() end)

    assert_error("Should error without filename in constructor table",
        function () sqlite{} end)
end

function test_sqlite3_exec()
    local db = sqlite3{filename=":memory:"}
    local ret, tail = db:exec([[CREATE TABLE IF NOT EXISTS test (
        id INTEGER PRIMARY KEY,
        uri TEXT,
        created FLOAT
    )]])
    assert_nil(ret)
    assert_nil(tail)

    assert_error("Should error when given empty SQL statement",
        function () db:exec(";") end)

    local ret, tail = db:exec([[SELECT * FROM test;]])
    assert_table(ret)
    assert_equal(0, #ret)
    assert_nil(tail)

    local ret, tail = db:exec([[INSERT INTO test VALUES(NULL, "google.com", 1234.45)]])
    assert_nil(ret)
    assert_nil(tail)

    local ret, tail = db:exec([[SELECT * FROM test;]])
    assert_table(ret)
    assert_equal(1, #ret)
    assert_nil(tail)

    ret = ret[1]
    assert_table(ret)
    assert_equal("google.com", ret.uri)
    assert_equal(1234.45, ret.created)

    local ret, tail = db:exec([[INSERT INTO test VALUES(:id, :uri, :created);]],
        { [":uri"] = "reddit.com", [":created"] = 1000 })

    assert_nil(ret)
    assert_nil(tail)

    local ret, tail = db:exec([[SELECT * FROM test;]])
    assert_table(ret)
    assert_equal(2, #ret)
    assert_nil(tail)

    ret = ret[2]
    assert_table(ret)
    assert_equal("reddit.com", ret.uri)
    assert_equal(1000, ret.created)

--    for i, row in ipairs(ret) do
--        for k,v in pairs(row) do
--            print("row", i, k, v)
--        end
--    end
end
