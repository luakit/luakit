------------------------------------------------------
-- URI parsing functions                            --
-- © 2011 Mason Larobina <mason.larobina@gmail.com> --
------------------------------------------------------

-- Get lua environment
local table = table
local string = string
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local type = type
local setmetatable = setmetatable
local getmetatable = getmetatable
local assert = assert
local rawset = rawset

-- Get luakit environment
local util = require "lousy.util"
local capi = { soup = soup }
local uri_encode = luakit.uri_encode
local uri_decode = luakit.uri_decode

module "lousy.uri"

local opts_metatable = {
    __tostring = function (opts)
        local ret, done = {}, {}
        -- Get opt order from metatable
        local mt = getmetatable(opts)
        -- Add original args first in order
        if mt and mt.order then
            for _, k in ipairs(mt.order) do
                local v = opts[k]
                if v and v ~= "" then
                    table.insert(ret, uri_encode(k) .. "=" .. uri_encode(v))
                    done[k] = true
                end
            end
        end
        -- Add new args
        for k, v in pairs(opts) do
            if not done[k] and v ~= "" then
                table.insert(ret, uri_encode(k) .. "=" .. uri_encode(v))
            end
        end
        -- Join query opts
        return table.concat(ret, "&")
    end,
    __add = function (op1, op2)
        assert(type(op1) == "table" and type(op2) == "table",
            "non-table operands")
        local ret = util.table.copy(op1)
        for k, v in pairs(op2) do
            ret[k] = v
        end
        return ret
    end,
}

--- Parse uri query
--@param query the query component of a uri
--@return table of options
function parse_query(query)
    local opts, order = {}, {}
    string.gsub(query or "", "&*([^&=]+)=([^&]+)", function (k, v)
        opts[k] = uri_decode(v)
        table.insert(order, k)
    end)
    -- Put order table in opts metatable
    local mt = util.table.clone(opts_metatable)
    mt.order = order
    return setmetatable(opts, mt)
end

-- Allowed URI table properties
local uri_allowed = { scheme = true, user = true, password = true,
    host = true, path = true, query = true, fragment = true, opts = true }

-- URI table metatable
local uri_metatable = {
    __tostring = function (uri)
        local t = util.table.clone(uri)
        t.query = tostring(t.opts)
        return capi.soup.uri_tostring(t)
    end,
    __add = function (op1, op2)
        assert(type(op1) == "table" and type(op2) == "table",
            "non-table operands")
        local ret = util.table.copy(op1)
        for k, v in pairs(op2) do
            assert(uri_allowed[k], "invalid property: " .. k)
            if k == "query" and type(v) == "string" then
                uri.opts = parse_query(v)
            else
                uri[k] = v
            end
        end
        return ret
    end,
}

-- Parse uri string and return uri table
function parse(uri)
    -- Get uri table
    local uri = capi.soup.parse_uri(uri)
    if not uri then return end
    -- Parse uri.query and set uri.opts
    uri.opts = parse_query(uri.query)
    uri.query = nil
    return setmetatable(uri, uri_metatable)
end

-- Duplicate uri object
function copy(uri)
    assert(type(uri) == "table", "not a table")
    return parse(tostring(uri))
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
