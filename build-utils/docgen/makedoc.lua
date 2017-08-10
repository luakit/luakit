#!/usr/bin/env luajit

local docgen_dir = "build-utils/"
local config_path = "doc/docgen.ld"

package.path = package.path .. ";" .. docgen_dir .. "?.lua"

local parse = require "docgen.parse"
local gen = require "docgen.gen"
local find_files = require("find_files").find_files

-- Load helpers

local load_file = function (path)
    local f = assert(io.open(path, "r"))
    local contents = f:read("*all")
    f:close()
    return contents
end

local function load_config_ld (path)
    local code = load_file(path)
    local conf = assert(loadstring(code))

    -- execute in sandbox
    local env = {}
    setfenv(conf, env)
    assert(pcall(conf))
    return env
end

local parse_module_files = function (files)
    local docs = {}
    for _, filename in ipairs(files) do
        print("Parsing '" .. filename .. "'...")
        local parsed = parse.parse_file(filename)
        docs[#docs+1] = parsed
    end
    table.sort(docs, function(a, b) return a.name < b.name end)
    return docs
end

local parse_pages_files = function (files)
    local pages = {}
    for _, filename in ipairs(files) do
        print("Reading '" .. filename .. "'...")
        local text = load_file(filename)
        local name, idx = text:match("^@name (.-)\n()")
        filename = filename:gsub(".*/([%w-]+).md", "%1")
        assert(filename:gmatch("[%w-]+.md"), "Bad page filename " .. filename)
        pages[#pages+1] = {
            name = assert(name, "no @name line found"),
            filename = filename,
            text = text:sub(idx),
        }
    end
    table.sort(pages, function(a, b) return a.filename < b.filename end)
    return pages
end

---

local config = load_config_ld(config_path)
local files = find_files(config.file, "%.lua$", config.file.exclude)

local docs = parse_module_files(files)
local pages = parse_pages_files(find_files(config.pages, "%.md$"))

-- Split into modules and classes
local module_docs = {}
local class_docs = {}
for _, doc in ipairs(docs) do
    if doc.module then table.insert(module_docs, doc) end
    if doc.class then table.insert(class_docs, doc) end
end

docs = {
    pages = pages,
    modules = module_docs,
    classes = class_docs,
    stylesheet = docgen_dir .. "docgen/style.css",
}

gen.generate_documentation(docs, config.dir)

-- vim: et:sw=4:ts=8:sts=4:tw=80
