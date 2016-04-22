#include "common/luautil.h"
#include "globalconf.h"

void
luaH_add_paths(lua_State *L, const gchar *config_dir)
{
    lua_getglobal(L, "package");
    if(LUA_TTABLE != lua_type(L, 1)) {
        warn("package is not a table");
        return;
    }
    lua_getfield(L, 1, "path");
    if(LUA_TSTRING != lua_type(L, 2)) {
        warn("package.path is not a string");
        lua_pop(L, 1);
        return;
    }

    /* compile list of package search paths */
    GPtrArray *paths = g_ptr_array_new_with_free_func(g_free);

#if DEVELOPMENT_PATHS
    /* allows for testing luakit in the project directory */
    g_ptr_array_add(paths, g_strdup("./lib"));
    g_ptr_array_add(paths, g_strdup("./config"));
#endif

    /* add users config dir (see: XDG_CONFIG_DIR) */
    if (config_dir)
        g_ptr_array_add(paths, g_strdup(config_dir));

    /* add system config dirs (see: XDG_CONFIG_DIRS) */
    const gchar* const *config_dirs = g_get_system_config_dirs();
    for (; *config_dirs; config_dirs++)
        g_ptr_array_add(paths, g_build_filename(*config_dirs, "luakit", NULL));

    /* add luakit install path */
    g_ptr_array_add(paths, g_build_filename(LUAKIT_INSTALL_PATH, "lib", NULL));

    const gchar *path;
    for (guint i = 0; i < paths->len; i++) {
        path = paths->pdata[i];
        /* Search for file */
        lua_pushliteral(L, ";");
        lua_pushstring(L, path);
        lua_pushliteral(L, "/?.lua");
        lua_concat(L, 3);
        /* Search for lib */
        lua_pushliteral(L, ";");
        lua_pushstring(L, path);
        lua_pushliteral(L, "/?/init.lua");
        lua_concat(L, 3);
        /* concat with package.path */
        lua_concat(L, 3);
    }

    g_ptr_array_free(paths, TRUE);

    /* package.path = "concatenated string" */
    lua_setfield(L, 1, "path");

    /* remove package module from stack */
    lua_pop(L, 1);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
