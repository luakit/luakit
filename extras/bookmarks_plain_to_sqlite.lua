local usage = [[Usage: luakit -c bookmarks_plain_to_sqlite.lua [bookmark plaintext path] [bookmark db path]

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

-- Store plain DB into 'data' var.
old_db = assert(io.open(old_db_path, "r"))
local data = old_db:read("*all")
assert(old_db:close())

-- Init new_db, otherwise sqlite queries will fail.
new_db = sqlite3{ filename = new_db_path }
new_db:exec("CREATE TABLE IF NOT EXISTS bookmarks (id INTEGER PRIMARY KEY, uri TEXT NOT NULL, title TEXT NOT NULL, desc TEXT NOT NULL, tags TEXT NOT NULL, created INTEGER, modified INTEGER )")

-- Fill
local url,tag

for line in data:gmatch("[^\n]*\n?") do

   if string.len(line) > 1 then

      print ("["..line.."]")

      -- Get url and tag (if present) from first line.
      _, _, url, tag = string.find(line, "([^\n\t]+)\t*([^\n]*)\n?")

      -- Optional yet convenient output.
      io.write(url)
      io.write("\t")
      io.write(tag)
      io.write("\n")

      -- DB insertion. Nothing will be overwritten. If URL and/or tag already exists, then a double is created.
      new_db:exec("INSERT INTO bookmarks VALUES (NULL, ?, ?, ?, ?, ?, ?)", 
                  {
                     url, "", "", tag or "",
                     os.time(), os.time()
                  })
      end
end

print("Import finished.")
print("\nVacuuming database...")
new_db:exec "VACUUM"
print("Vacuum done.")

luakit.quit(0)