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
    local ret = db:exec([[CREATE TABLE IF NOT EXISTS test (
        id INTEGER PRIMARY KEY,
        uri TEXT,
        created FLOAT
    )]])
    assert_nil(ret)

    assert_pass(function () db:exec(";") end)

    local ret = db:exec(";")
    assert_nil(ret)

    local ret = db:exec([[SELECT * FROM test;]])
    assert_table(ret)
    assert_equal(0, #ret)

    local ret = db:exec([[INSERT INTO test VALUES(NULL, "google.com", 1234.45)]])
    assert_nil(ret)

    local ret = db:exec([[SELECT * FROM test;]])
    assert_table(ret)
    assert_equal(1, #ret)

    ret = ret[1]
    assert_table(ret)
    assert_equal("google.com", ret.uri)
    assert_equal(1234.45, ret.created)

    local ret = db:exec([[INSERT INTO test VALUES(:id, :uri, :created);]],
        { [":uri"] = "reddit.com", [":created"] = 1000 })

    assert_nil(ret)

    local ret = db:exec([[SELECT * FROM test;]])
    assert_table(ret)
    assert_equal(2, #ret)

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

function test_compile_statement()
    local db = sqlite3{filename=":memory:"}
    local ret, tail = db:exec([[CREATE TABLE IF NOT EXISTS test (
        id INTEGER PRIMARY KEY,
        uri TEXT,
        created FLOAT
    )]])
    assert_nil(ret)
    assert_nil(tail)

    -- Compile some statements
    local insert, tail = db:compile([[INSERT INTO test VALUES(:id, :uri, :created);]])
    assert_equal("sqlite3::statement", type(insert))
    assert_nil(tail)

    local select_all, tail = db:compile([[SELECT * FROM test;]])
    assert_equal("sqlite3::statement", type(select_all))
    assert_nil(tail)

    local ret = insert:exec{ [":uri"] = "google.com", [":created"] = 1000 }
    assert_nil(ret)
    local ret = insert:exec{ [":uri"] = "reddit.com", [":created"] = 12.34 }
    assert_nil(ret)

    local ret = select_all:exec()
    assert_table(ret)
    assert_equal(2, #ret)

    assert_table(ret[1])
    assert_equal("google.com", ret[1].uri)
    assert_equal(1000, ret[1].created)
    assert_table(ret[2])
    assert_equal("reddit.com", ret[2].uri)
    assert_equal(12.34, ret[2].created)

    -- Re-run last statement with same bound values
    local ret = insert:exec()
    assert_nil(ret)

    local ret = select_all:exec()
    assert_table(ret)
    assert_equal(3, #ret)

    assert_table(ret[3])
    assert_equal("reddit.com", ret[3].uri)
    assert_equal(12.34, ret[3].created)
end
