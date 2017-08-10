@name Files and Directories
# Files and Directories

There are three main directories that luakit and its modules will search in
order to load user data and configuration, such as user stylesheets,
userscripts, and adblock filterlists. These directories are the _configuration_
directory, the _data_ directory, and the _cache_ directory respectively.

## Configuration directory

The configuration directory is the first directory examined when searching for
the `rc.lua` startup script. It stores Lua configuration files and personal Lua
modules. Any Lua files within this directory can be loaded with a `require()`
call.

### How do I find the path to the configuration directory?

To find the path to the current configuration directory, run the following
command:

    :lua w:notify(luakit.config_dir)

## Data directory

The data directory is used for all luakit files that are not Lua files.
This includes any databases used by luakit and its modules, such as
the history, bookmarks, and cookies databases. It also includes user
stylesheets (CSS files), userscripts, and adblock filterlists.

Lua files should generally _not_ go in the data directory; instead, they
should go in the configuration directory, where they can be loaded via
`require()`. A slightly-confusing exception is the `forms.lua` file,
which is read by the @ref{formfiller} module. It uses a domain-specific
language instead of Lua, and is not a standalone module; instead, it is
loaded by the @ref{formfiller} module as a data file, and so it belongs
in luakit's data directory.

### Where should I put {userstyles, filterlists, ...}?

1. First, browse to the built-in documentation page for that module. A list of all
modules is available at the index page at <luakit://help/doc/index.html>.
1. Next, check under the **Files and Directories** heading for module-specific
   directions.

### How do I find the path to the data directory?

To find the path to the current data directory, run the following
command:

    :lua w:notify(luakit.data_dir)

## Cache directory

Users will rarely have to modify files in luakit's cache directory. This is the
cache directory used by WebKit and a few other modules that need to store files
on a temporary basis, such as the @ref{viewpdf} module.

If this directory is taking up too much disk space, it is safe to delete
some or all of its contents; conversely, Lua modules should never store
files in this directory if those files need to be kept, as they may be
deleted without warning.

### How do I find the path to the cache directory?

To find the path to the current cache directory, run the following
command:

    :lua w:notify(luakit.cache_dir)

