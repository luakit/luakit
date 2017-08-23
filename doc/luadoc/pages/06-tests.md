@name Running the Test Suite
#Running the Test Suite

##Test System

Luakit's tests are currently divided into two main groups; *style* tests
and *asynchronous* tests. Style tests check the Luakit source code for
formatting consistency. Asynchronous tests run an isolated instance of
Luakit with a special configuration file and run through a series of
actions determined by the test case.

##Running Tests

To run all of Luakit's tests, run `make run-tests`, or run the test
runner directly with `./tests/run_test.lua`. This will run all tests in
series.

To run a subset of Luakit's tests, run the test runner with one
or more directory/file-name prefixes as arguments. For example,
`./tests/run_test.lua tests/style/` will run only the code style
tests. Note that asynchronous tests are located in `tests/async/` (not
`tests/asynchronous/`).

##Test API

###Style tests

Style tests generally use the `tests.lib` function `find_files()` to
retrieve a set of files of interest, before loading the contents of each
file for examination.

Reporting errors is done via the `tests.lib` function
`format_file_errors()`.

###Asynchronous tests

Each test file returns a table of test functions, keyed by test name.
These are internally converted to coroutines, allowing test functions
to be suspended and resumed. Test functions can access the `tests.lib`
module, which contains several useful interfaces.
