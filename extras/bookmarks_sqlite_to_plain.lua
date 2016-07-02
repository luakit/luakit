-- USER CONFIG

local sep = " "

-- END OF USER CONFIG

local usage = [[Usage: luakit -c bookmarks_sqlite_to_plain.lua [bookmark db path] [bookmark plain path]

DB scheme is

    bookmarks (
        id INTEGER PRIMARY KEY,
        uri TEXT NOT NULL,
        title TEXT NOT NULL,
        desc TEXT NOT NULL,
        tags TEXT NOT NULL,
        created INTEGER,
        modified INTEGER
    );
]]

local old_db_path, new_db_path = unpack(uris)

if not old_db_path or not new_db_path then
   io.stdout:write(usage)
   luakit.quit(1)
end

-- One-pass file read into 'data' var.
new_db = assert(io.open(new_db_path, "w"))

-- Open old_db
old_db = sqlite3{ filename = old_db_path }

-- Load all db values to a string variable.
local rows = old_db:exec [[ SELECT * FROM bookmarks ]]

-- Iterate over all entries.
-- Note: it could be faster to use one single concatenation for all entries, but
-- it would be much more code and not so flexible. It is desirable to focus on
-- clarity. After all, only a few hundred lines are handled.
for _, b in ipairs(rows) do

   -- Change %q for %s to remove double quotes if needed.
   -- You can toggle the desired fields with comments.
   local outputstr = 
      string.format("%q%s", b.uri or "", sep) .. 
      string.format("%q%s", b.title or "", sep) ..
      string.format("%q%s", b.desc or "", sep) ..
      string.format("%q%s- ", b.tags or "", sep) ..
      ((b.created or "" ) .. sep) ..
      ((b.modified or "" ) .. sep) ..
      "\n"

   -- Write entry to file.
   new_db:write(outputstr)
end


print("Export done.")

assert(new_db:close())

luakit.quit(0)