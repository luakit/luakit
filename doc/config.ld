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
project = "Luakit"
title = "Luakit API Reference"
description = "A fork of a fast, small, webkit based browser framework extensible by Lua."
sort = true
not_luadoc = true

-- Make the docs prettier
pretty = "lua"
style = "!pale"
backtick_references = true
merge = true
use_markdown_titles = true
wrap = true

topics = {
    "00-authors.md",
}

-- vim: et:sw=4:ts=8:sts=4:tw=80:ft=lua
