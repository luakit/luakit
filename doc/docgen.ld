-- List of sources used to generate Lua API documentation
-- Must be kept in sync with Makefile

file = {
    "doc/luadoc",
    "lib",
    "common/clib",
    "tests/lib.lua",
    exclude = {
        "lib/markdown.lua",
        "lib/lousy/init.lua",
        "lib/lousy/widget/init.lua",
    },
}

pages = {
    "doc/luadoc/pages/",
}

dir = "doc/apidocs"

-- vim: et:sw=4:ts=8:sts=4:tw=80:ft=lua
