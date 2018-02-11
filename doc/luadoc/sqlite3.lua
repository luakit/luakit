--- Lightweight SQLite database interface.
--
-- DOCMACRO(available:web)
--
-- This module provides Lua access to SQLite databases. These are used
-- for a number of purposes by the default modules, including storing
-- user bookmarks, cookies, and browsing history.
--
-- # Opening a database
--
-- To create a new `sqlite3` instance and connect to a database, use the
-- `sqlite3` constructor:
--
--     local db = sqlite3{ filename = "path/to/database.db" }
--
-- @class sqlite3
-- @author Mason Larobina
-- @copyright 2011 Mason Larobina <mason.larobina@gmail.com>

--- @method exec
--
-- Compile and execute the SQL query string `query` against the database.
-- The `sqlite3` instance must have been opened successfully.
--
-- @tparam string query A SQL query, comprised of one or more SQL statements.
-- @tparam[opt] table bindings A table of values to bind to each SQL statement.
-- @default `{}`
-- @treturn table A table representing the query result.

--- @method close
-- Close a database and release related resources.

--- @method compile
-- Compile a SQL statement into a newly-created `sqlite3::statement` instance.
-- @tparam string statement A SQL statement.
-- @treturn sqlite3::statement A newly-created instance representing a compiled statement.

--- @method changes
-- Get the number of rows that were added, removed, or changed by the
-- most recently executed `INSERT`, `UPDATE` or `DELETE` statement.
-- @treturn number The number of modified rows.

--- @property filename
--
-- The path to the database that the `sqlite3` instance is connected to.
--
-- @type string
-- @readonly

-- vim: et:sw=4:ts=8:sts=4:tw=80
