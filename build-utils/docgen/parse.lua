#!/usr/bin/env luajit

local function_set

local check_unique = function (name, t)
    local prefix = t == "signal" and "s" or "-"
    assert(not function_set[name .. prefix], "Duplicate name " .. name)
    function_set[name .. prefix] = true
end

local advance = function (block)
    local ret = table.remove(block, 1)
    block.i = block.i + 1
    return ret
end

local peel_off_text_block = function (block)
    local lines = {}
    while block[1] and not (block[1]:match("^@%w+") and not block[1]:match("^@ref{")) do
        table.insert(lines, advance(block))
    end
    return table.concat(lines, "\n")
end

local peel_off_type_string = function (line)
    local start, typestr, rem = line:match("^%@t(%w+ )(%S+)%s?(.*)$")
    if start and typestr then
        return "@" .. start .. rem, typestr
    else
        return line, nil
    end
end

local parse_error = function (block, ...)
    assert(block[1])
    local hdr = ("Error at line %s: "):format(block.start + block.i)
    error(hdr .. string.format(...))
end

local expect = function (block, pat, err, should_advance)
    if not block[1] then error("Early EOF: " .. err) end
    local rets = {}
    for _, p in ipairs(type(pat) == "string" and {pat} or pat) do
        rets = #rets > 0 and rets or {block[1]:match(p)}
    end
    if #rets == 0 then parse_error(block, err) end
    if should_advance ~= false then advance(block) end
    return unpack(rets)
end

local parse_doc_header_line = function (doc, line)
    local key, val = line:match("^%@([%w_]+) (.+)$")
    if not (key and val) then return end

    if key == "module" or key == "class" or key == "submodule" then
        doc.name = val
        doc[key] = true
    elseif not doc[key] then
        doc[key] = val
    elseif type(doc[key]) == "table" then
        table.insert(doc[key], val)
    else
        return "Duplicate header line @"..key
    end
end

local parse_optional_at_type_line = function (item, block)
    if not block[1] or not block[1]:find("^@type") then return end
    assert(not item.typestr, "Type already set")
    item.typestr = expect(block, "^%@type (%S+)$", "Bad @type line")
end

local parse_at_read_write_line = function (item, block)
    local line = advance(block):sub(2)
    item[line] = true
end

local parse_at_default_line = function (item, block)
    if not (block[1] and block[1]:find("^@default")) then return end
    local default = expect(block, "^%@default (.+)", "Missing @default")
    item.default = (default .. peel_off_text_block(block)):gsub("^%s+",""):gsub("[%s%.]+$","")
end

local parse_at_deprecated_line = function (item, block)
    if not block[1]:find("^@deprecated") then return end
    local deprecated = expect(block, "^%@deprecated (.+)", "Missing @deprecated")
    item.deprecated = (deprecated .. peel_off_text_block(block)):gsub("^%s+",""):gsub("[%s%.]+$","")
end

local function parse_first_file_block(doc, block)
    doc.author = {}
    doc.copyright = {}
    doc.tagline = advance(block)

    -- Separate block into markdown and @-lines
    local atlines = {}
    for i, line in ipairs(block) do
        if line:match("^@%w+") and not line:match("^@ref{") then
            table.insert(atlines, line)
            block[i] = ""
        end
    end

    -- Parse atlines
    for _, line in ipairs(atlines) do
        local err = parse_doc_header_line(doc, line)
        if err then error(err) end
    end

    doc.desc = table.concat(block, "\n")

    assert(doc.module or doc.submodule or doc.class, "Missing @module / @submodule / @class")
    -- assert(doc.author[1], "Missing @author")
    -- assert(doc.copyright[1], "Missing @copyright")
end

local function parse_at_function_line(item, block, func_type)
    if item.type then parse_error(block, "@%s line inside %s block", func_type, item.type) end
    item.type = func_type -- "function" / "method" / "signal" / "callback"
    item.params = item.params or {}
    item.returns = item.returns or {}
    item.name = block[1]:match("^%@function (%S+)$")
             or block[1]:match("^%@method (%S+)$")
             or block[1]:match("^%@signal (%S+)$")
             or block[1]:match("^%@callback (%S+)$")
             or parse_error(block, "Missing %s name", func_type)
    check_unique(item.name, item.type)
    assert((not not item.name:match("_cb$")) == (item.type == "callback"), "Only/all callback names end in _cb")
    advance(block)
end

local function parse_at_param_line(item, block)
    local param, line = {}, advance(block)

    -- Handle [opt]
    if line:match("^%@t?param%[opt%] ") then
        line = line:gsub("^%@(t?param)%[opt%] ", "@%1 ")
        param.optional = true
    end

    local typestr, name, prefix
    line, typestr = peel_off_type_string(line)
    name, prefix = line:match("^%@param (%S+)%s?(.*)$")

    param.typestr = typestr
    param.name = name
    param.desc = (prefix or "") .. "\n" .. peel_off_text_block(block)

    parse_optional_at_type_line(param, block)

    if param.optional then
        parse_at_default_line(param, block)
    end

    item.params = item.params or {}
    table.insert(item.params, param)
end

local function parse_at_property_line(item, block)
    assert(not item.type, "Misplaced @property line")
    item.type = "property"
    item.name = advance(block):match("^%@property (%S+)$")
    check_unique(item.name, item.type)
end

local function parse_at_return_line(item, block)
    local ret, line = {}, advance(block)

    -- Handle [n]
    ret.group = tonumber(line:match("^%@t?return%[(%d+)%] "))
    if ret.group then
        line = line:gsub("^%@(t?return)%[%d+%] ", "@%1 ")
    end

    line, ret.typestr = peel_off_type_string(line)
    local prefix = line:match("^%@return (.*)$")

    ret.desc = (prefix or "") .. "\n" .. peel_off_text_block(block)

    item.returns = item.returns or {}
    table.insert(item.returns, ret)
end

local function parse_file_block_part(item, block)
    local at = block[1]:match("^@(%w+)")
    if at == "function" or at == "method" or at == "signal" or at == "callback" then
        parse_at_function_line(item, block, at)
    elseif at == "param" or at == "tparam" then
        parse_at_param_line(item, block)
    elseif at == "return" or at == "treturn" then
        parse_at_return_line(item, block)
    elseif at == "property" then
        parse_at_property_line(item, block)
    elseif at == "readonly" or at == "readwrite" then
        parse_at_read_write_line(item, block)
    elseif at == "default" then
        parse_at_default_line(item, block)
    elseif at == "type" then
        parse_optional_at_type_line(item, block)
    elseif at == "deprecated" then
        parse_at_deprecated_line(item, block)
    elseif at then
        parse_error(block, "Unexpected at-line '" .. at .. "'")
    else
        item.desc = peel_off_text_block(block)
    end
end

local function parse_file_block(block)
    local item = {}
    while block[1] do parse_file_block_part(item, block) end
    return item
end

local function check_parsed_file_block(item)
    -- TODO: handle missing name!
    assert(item.desc, item.type .. " " .. item.name .. " missing description")
end

local function parse_file_blocks (blocks)
    local doc = {}
    parse_first_file_block(doc, blocks[1])
    for i=2,#blocks do
        local item = parse_file_block(blocks[i])
        check_parsed_file_block(item)
        local groupname = item.type == "property" and "properties" or item.type .. "s"
        doc[groupname] = doc[groupname] or {}
        table.insert(doc[groupname], item)
    end
    return doc
end

local function read_file_comment_blocks(path)
    local blocks, block = {}, nil
    local f = io.open(path, "r")
    local line_i = 0
    for line in f:lines() do
        line_i = line_i + 1
        if (not block and line:match("^%-%-%-")) or (line_i == 1 and line:match("^%-%-")) then
            block = { start = line_i, i = 0 }
            table.insert(blocks, block)
        end
        if block then
            table.insert(block, line)
            if not line:match("^%-%-") then block = nil end
        end
    end
    f:close()
    return blocks
end

local function convert_comment_block_last_line(block)
    local line = block[#block]
    if line == "" then return nil end

    local name = line:match("_M%.([%w%d_.]+)") or line:match("^function ([%w%d_.]+)")
    local is_function = line:match("^function ") or line:match("= ?function")
    local type = is_function and "function" or "property"
    if name then
        return string.format("-- @%s %s", type, name)
    end
    parse_error(block, "Couldn't parse name from line")
end

local function convert_file_comment_blocks(blocks)
    for i=#blocks,1,-1 do
        local block = blocks[i]
        local line = block[#block]
        if not line:match("^%-%-") and i == 1 then
            block[#block] = nil
        elseif line:match("^local ") then
            table.remove(blocks, i)
        elseif not line:match("^%-%-") then
            block[#block] = convert_comment_block_last_line(block)
        end
    end
    -- Strip comment dashes and trailing spaces, drop @local blocks
    for i=#blocks,1,-1 do
        local block = blocks[i]
        for j, line in ipairs(block) do
            block[j] = line:gsub("^%-%-%-? ?", ""):gsub("%s+$","")
            if block[j] == "@local" then table.remove(blocks, i) break end
            if block[j] == "@usage" then block[j] = "### Usage" end
        end
    end
end

return {
    parse_file = function (path)
        function_set = {}
        local blocks = read_file_comment_blocks(path)
        if #blocks == 0 then error("no comment blocks found in file") end
        convert_file_comment_blocks(blocks)
        return parse_file_blocks(blocks)
    end,
}

-- vim: et:sw=4:ts=8:sts=4:tw=80
