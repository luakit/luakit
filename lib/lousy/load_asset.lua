local io = require "io"
local assert = assert
local string = string
local io = io
local setmetatable = setmetatable
local package = package
local pairs = pairs
local table = table
local util = require "lousy.util"

-- Get luakit environment
local capi = {
    luakit = luakit
}

module("lousy.load_asset")

local search_dirs = {} -- Directories where assets may be.

for _, el in pairs(util.string.split(package.path, ";")) do
   if string.sub(el, -6) == "/?.lua" then
      table.insert(search_dirs, string.sub(el, 1,-6))
   end
end

local data = {}

-- Search all the assets, and load it if exists.
local function search_load_asset(path, memorize)
   if memorize and data[path] then
      return data[path]
   end
   for _, dir in pairs(search_dirs) do
      local got = io.open(dir .. path, "r")
      if got then
         local ret = got:read("*a")
         if memorize then
            data[path] = ret
         end
         got:close()
         return ret
      end
   end
   return nil
end

setmetatable(_M, { __call = function (_, ...) return search_load_asset(...) end })
