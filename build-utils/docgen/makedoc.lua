#!/usr/bin/env luajit

local docgen_dir = "build-utils/"
local config_path = "doc/docgen.ld"

package.path = package.path .. ";" .. docgen_dir .. "?.lua"

local lfs = require "lfs"
local parse = require "docgen.parse"
local gen = require "docgen.gen"
local find_files = require("find_files").find_files

-- Load doc stylesheet

local f = assert(io.open(docgen_dir .. "docgen/style.css", "r"))
local style = f:read("*a")
f:close()

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
        pages[#pages+1] = {
            name = assert(name, "no @name line found"),
            text = text:sub(idx),
        }
    end
    table.sort(pages, function(a, b) return a.name < b.name end)
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
}

local sidebar_html = gen.generate_sidebar_html(docs)

local mkdir = function (path)
    if lfs.attributes(path, "mode") == "directory" then return end
    assert(lfs.mkdir(path))
end

local out_dir = assert(config.dir, "No output directory specified")
out_dir = out_dir:match("/$") and out_dir or out_dir .. "/"
mkdir(out_dir)
for _, section_name, section_docs in ipairs{"modules", "classes"} do
    local section_docs = docs[section_name]
    for i, doc in ipairs(section_docs) do
        local path = out_dir .. section_name .. "/" .. doc.name .. ".html"
        mkdir(out_dir .. section_name)
        print("Generating '" .. path .. "'...")

        local f = io.open(path, "w")
        f:write(gen.generate_module_html(doc, style, sidebar_html))
        f:close()
    end
end

for i, page in ipairs(pages) do
    local path = out_dir .. "pages/" .. page.name .. ".html"
    mkdir(out_dir .. "pages")
    print("Generating '" .. path .. "'...")

    local f = io.open(path, "w")
    f:write(gen.generate_page_html(page, style, sidebar_html))
    f:close()
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
