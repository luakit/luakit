require "lunit"
module("test_webview_javascript", lunit.testcase, package.seeall)

-- Dummy webview widget used for all the tests.
local view = widget{type="webview"}

function test_eval_js_return_types()
    assert_equal(view:eval_js([["a string";]]), "a string")
    assert_equal(view:eval_js("100 + 200;"), 300)
    assert_equal(view:eval_js("true;"), true)
    assert_equal(view:eval_js("undefined;"), nil)
    assert_equal(view:eval_js("null;"), nil)
    --assert_table(view:eval_js("{};")) TODO: Add support for table types
end

function test_catch_js_exception()
    local ret, err = view:eval_js("unknownVariable;")
    assert_nil(ret)
    assert_match("^ReferenceError:", err)
end

function test_register_function()
    view:register_function("my_add", function (a, b) return a + b end)
    assert_equal(view:eval_js("my_add(40,50);"), 90)
end

function test_register_function_error()
    view:register_function("raise_error", function (msg) error(msg) end)
    local ret, err = view:eval_js([[raise_error("Some error message");]])
    assert_nil(ret)
    assert_match("Some error message$", err)
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
    assert_nil(ret)
    assert_nil(err)

    local ret, err = view:eval_js([[check_args(100, "a string", null, undefined);]])
    assert_nil(ret)
    assert_match("assertion failed!$", err)

    local ret, err = view:eval_js([[check_args(function() {});]])
    assert_nil(ret)
    assert_match("^bad argument #0 ", err)
end
