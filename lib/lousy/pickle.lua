--- lousy.pickle library.
--
-- A table serialization utility for lua. Freeware.
--
-- *Note: The serialization format may change without notice. This
-- should be treated as an opaque interface.*
--
-- @module lousy.pickle
-- @author Steve Dekorte, http://www.dekorte.com
-- @copyright 2000 Steve Dekorte


local Pickle = {
    clone = function (t) local nt={}; for i, v in pairs(t) do nt[i]=v end return nt end
}

function Pickle:pickle_(root)
    if type(root) ~= "table" then
        error("can only pickle tables, not ".. type(root).."s")
    end
    self._tableToRef = {}
    self._refToTable = {}
    local savecount = 0
    self:ref_(root)
    local s = ""

    while table.getn(self._refToTable) > savecount do
        savecount = savecount + 1
        local t = self._refToTable[savecount]
        s = s.."{\n"
        for i, v in pairs(t) do
                s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
        end
        s = s.."},\n"
    end

    return string.format("{%s}", s)
end

function Pickle:value_(v)
    local vtype = type(v)
    if vtype == "string" then return string.format("%q", v)
    elseif vtype == "number" then return v
    elseif vtype == "boolean" then return tostring(v)
    elseif vtype == "table" then return "{"..self:ref_(v).."}"
    else error("pickle a "..type(v).." is not supported")
    end
end

function Pickle:ref_(t)
    local ref = self._tableToRef[t]
    if not ref then
        if t == self then error("can't pickle the pickle class") end
        table.insert(self._refToTable, t)
        ref = table.getn(self._refToTable)
        self._tableToRef[t] = ref
    end
    return ref
end

local _M = {}

--- Convert a table into a string that can be saved to disk.
-- @tparam table t The table to serialize.
-- @treturn string The string representing the table contents.
_M.pickle = function(t)
    return Pickle:clone():pickle_(t)
end

--- Convert a string previously created with `pickle()` to a table.
-- @tparam string s The string previously created with `pickle()`.
-- @treturn table A table corresponding to the given string.
_M.unpickle = function(s)
    if type(s) ~= "string" then
        error("can't unpickle a "..type(s)..", only strings")
    end
    local gentables = loadstring("return "..s)
    local tables = gentables()

    for tnum = 1, table.getn(tables) do
        local t = tables[tnum]
        local tcopy = {}; for i, v in pairs(t) do tcopy[i] = v end
        for i, v in pairs(tcopy) do
            local ni, nv
            if type(i) == "table" then ni = tables[i[1]] else ni = i end
            if type(v) == "table" then nv = tables[v[1]] else nv = v end
            t[i] = nil
            t[ni] = nv
        end
    end
    return tables[1]
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
