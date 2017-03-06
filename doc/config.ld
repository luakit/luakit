file = {
    "luadoc",
    "../lib",
    "../common/clib/",
    exclude = {
        "../lib/markdown.lua"
    },
}
format='discount'
dir = "apidocs"
style='!fixed'
project = "Luakit"
title = "Luakit API Reference"
description = "A fork of a fast, small, webkit based browser framework extensible by Lua."
sort = true
not_luadoc = true

topics = {
    "00-authors.md",
}

-- vim: et:sw=4:ts=8:sts=4:tw=80
