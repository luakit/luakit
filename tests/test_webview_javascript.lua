require "lunit"
module("test_webview_javascript", lunit.testcase, package.seeall)

-- Dummy webview widget used for all the tests.
local view = widget{type="webview"}

function test_eval_js_return()
    assert_equal("a string", view:eval_js([["a string";]]))
    assert_equal(300, view:eval_js("100 + 200;"))
    assert_equal(true, view:eval_js("true;"))
    assert_equal(nil, view:eval_js("undefined;"))
    assert_equal(nil, view:eval_js("null;"))
    --assert_table(view:eval_js("{};")) TODO: Add support for table types

    local ret, err = view:eval_js("[10,20,30];")
    assert_equal(nil, err)
    assert_table(ret)
    assert_equal(3, #ret)
    assert_equal("10,20,30", table.concat(ret, ","))

    local ret, err = view:eval_js([=[var o = {a_key: "Some string"}; o]=])
    assert_equal(nil, err)
    assert_table(ret)
    assert_equal(0, #ret)
    assert_equal("Some string", ret.a_key)

    local ret, err = view:eval_js([=[
        var o = { an_array: [10,20,30, { foo: "bar" }] };
        o;
    ]=]);
    assert_equal(nil, err)
    assert_table(ret)
    assert_equal("10,20,30", table.concat(ret.an_array, ",", 1, 3))
    assert_table(ret.an_array)
    assert_table(ret.an_array[4])
    assert_equal("bar", ret.an_array[4].foo)
end

function test_catch_js_exception()
    local ret, err = view:eval_js("unknownVariable;")
    assert_match("^ReferenceError:", err)
    assert_nil(ret)
end

function test_register_function()
    view:register_function("my_add", function (a, b) return a + b end)
    assert_equal(90, view:eval_js("my_add(40,50);"))
end

function test_register_function_error()
    view:register_function("raise_error", function (msg) error(msg) end)
    local ret, err = view:eval_js([[raise_error("Some error message");]])
    assert_match("Some error message$", err)
    assert_nil(ret)
end

function test_register_function_args()
    view:register_function("check_args", function (a_string, a_num, a_bool, a_undefined, a_null)
        orig_assert(type(a_string) == "string" and a_string == "a string")
        orig_assert(type(a_num) == "number" and a_num == 100)
        orig_assert(type(a_bool) == "boolean" and a_bool)
        orig_assert(type(a_undefined) == "nil")
        orig_assert(type(a_null) == "nil")
    end)

    local ret, err = view:eval_js([[check_args("a string", 100, true, undefined, null);]])
    assert_equal(nil, err)
    assert_nil(ret)

    local ret, err = view:eval_js([[check_args(100, "a string", null, undefined);]])
    assert_match("assertion failed!$", err)
    assert_nil(ret)
end

function test_register_function_return()
    view:register_function("return_num", function () return 100 end)
    local ret, err = view:eval_js("return_num();")
    assert_equal(nil, err)
    assert_equal(100, ret)

    view:register_function("return_string", function () return "a string" end)
    local ret, err = view:eval_js("return_string();")
    assert_equal(nil, err)
    assert_equal("a string", ret)

    view:register_function("return_bool", function () return true end)
    local ret, err = view:eval_js("return_bool();")
    assert_equal(nil, err)
    assert_equal(true, ret)

    view:register_function("return_nil", function () return nil end)
    local ret, err = view:eval_js("return_nil();")
    assert_equal(nil, err)
    assert_nil(ret)

    view:register_function("return_array", function ()
        return { [200] = 200, key = "val", 10,20,30, [100] = "donkey"}
    end)
    local ret, err = view:eval_js([=[return_array().join(",");]=])
    assert_equal(nil, err)
    assert_equal("10,20,30,donkey,200,val", ret)

    view:register_function("return_object", function ()
        return { a = "Some", b = "string", [200] = "e" }
    end)
    local ret, err = view:eval_js([=[
        var o = return_object();
        o["a"] + " " + o["b"];
    ]=])
    assert_equal(nil, err)
    assert_equal("Some string", ret)

    view:register_function("return_sub_array", function () return {{10,20,{30}}} end)
    local ret, err = view:eval_js([=[
        var a = return_sub_array();
        a[0][0] + a[0][1] + a[0][2][0];
    ]=])
    assert_equal(nil, err)
    assert_equal(60, ret)
end
