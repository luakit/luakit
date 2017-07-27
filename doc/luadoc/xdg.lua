--- XDG Base Directory Specification paths.
--
-- DOCMACRO(builtin)
--
-- This module provides access to the directories defined by the XDG
-- Base Directory specification. With this module, Lua scripts can
-- determine the best place to store and look for various types of data.
--
-- The full XDG Base Directory specification is available
-- [here](http://standards.freedesktop.org/basedir-spec/latest/).
--
-- ### Usage notes
--
-- - None of the returned directory paths end with a `/`.
-- - The @ref{xdg/cache_dir}, @ref{xdg/config_dir}, and @ref{xdg/data_dir} directories are the system
--   cache, config, and user data directories respectively. Each of
--   these directories contains a `luakit` sub-directory.
--   Lua modules should use the `luakit` sub-directories to store and read data.
--
-- @module xdg
-- @author Aidan Holm
-- @author Mason Larobina
-- @copyright 2017 Aidan Holm
-- @copyright 2011 Mason Larobina

--- @field cache_dir
-- Get the base directory in which Luakit stores non-essential cached
-- data. Data stored in this location may be removed in order to free up
-- disk space. The returned directory is the XDG cache directory, not the
-- `luakit` sub-directory within it that Luakit uses.
--
-- Example value: `/home/user/.cache`
--
-- @type string
-- @readonly

--- @field config_dir
-- Get the base directory in which Luakit's configuration is stored.
-- The returned directory is the XDG config directory, not the
-- `luakit` sub-directory within it that Luakit uses.
--
-- Example value: `/home/user/.config`
--
-- @type string
-- @readonly

--- @field data_dir
-- Get the base directory in which application/module data is stored.
-- The returned directory is the XDG user data directory, not the
-- `luakit` sub-directory within it that Luakit uses.
--
-- Example value: `/home/user/.local/share`
-- @type string
-- @readonly

--- @field desktop_dir
-- Get the full path to the user's desktop directory.
--
-- Example value: `/home/user/Desktop`
-- @type string
-- @readonly

--- @field documents_dir
-- Get the full path to the user's documents directory.
--
-- Example value: `/home/user/Documents`
-- @type string
-- @readonly

--- @field download_dir
-- Get the full path to the user's download directory.
--
-- Example value: `/home/user/Downloads`
-- @type string
-- @readonly

--- @field music_dir
-- Get the full path to the user's music directory.
--
-- Example value: `/home/user/Music`
-- @type string
-- @readonly

--- @field pictures_dir
-- Get the full path to the user's pictures directory.
--
-- Example value: `/home/user/Pictures`
-- @type string
-- @readonly

--- @field public_share_dir
-- Get the full path to the user's shared directory.
--
-- Example value: `/home/user/Public`
-- @type string
-- @readonly

--- @field templates_dir
-- Get the full path to the user's templates directory.
--
-- Example value: `/home/user/.templates`
-- @type string
-- @readonly

--- @field videos_dir
-- Get the full path to the user's videos directory.
--
-- Example value: `/home/user/Videos`
-- @type string
-- @readonly

--- @field system_data_dirs
-- Get an array of paths where system data should be loaded from.
-- @type {string}
-- @readonly

--- @field system_config_dirs
-- Get an array of paths where system configuration should be loaded from.
-- @type {string}
-- @readonly

-- vim: et:sw=4:ts=8:sts=4:tw=80
