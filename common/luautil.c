/*
 * Copyright © 2016 Aidan Holm <aidanholm@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include <lauxlib.h>
#include <lualib.h>
#include <string.h>

#include "common/luautil.h"
#include "common/log.h"
#include "buildopts.h"

gint
luaH_traceback(lua_State *L, gint min_level)
{
    gint top = lua_gettop(L);

    lua_Debug ar;
    gint max_level;
    gint loc_pad = 0;

#define AR_SRC(ar) \
    (g_strstr_len((ar).source, 3, "@./") ? (ar).source+3 : \
     (ar).source[0] == '@'               ? (ar).source+1 : \
     (ar).short_src)
#define LENF(fmt, ...) \
    (snprintf(NULL, 0, fmt, ##__VA_ARGS__))

    if (!lua_getstack(L, min_level, &ar)) {
        lua_pushliteral(L, "");
        return 1;
    }

    /* Traverse the stack to determine max level and padding sizes */
    for (gint level = min_level; lua_getstack(L, level, &ar); level++) {
        lua_getinfo(L, "Sl", &ar);

        max_level = level;

        gint cur_pad = LENF("%s:%d", AR_SRC(ar), ar.currentline);
        if (cur_pad > loc_pad) loc_pad = cur_pad;
    }

    gint level_pad = LENF("%d", max_level);

    for (gint level = min_level; level <= max_level; level++) {
        lua_getstack(L, level, &ar);
        lua_getinfo(L, "Sln", &ar);

        /* Current stack level */
        gint shown_level = level - min_level + 1;
        lua_pushliteral(L, ANSI_COLOR_GRAY "(");
        for (gint i = level_pad - LENF("%d", shown_level); i > 0; i--)
            lua_pushliteral(L, " ");
        lua_pushinteger(L, shown_level);
        lua_pushliteral(L, ")" ANSI_COLOR_RESET " ");

        /* Current location, padded */
        if (g_str_equal(ar.what, "C")) {
            lua_pushliteral(L, "[C]");
            for (gint i = loc_pad - strlen("[C]"); i > 0; i--)
                lua_pushliteral(L, " ");
        } else {
            const char *src = AR_SRC(ar);
            lua_pushstring(L, src);
            lua_pushliteral(L, ":");
            lua_pushinteger(L, ar.currentline);
            for (gint i = loc_pad - LENF("%s:%d", src, ar.currentline); i > 0; i--)
                lua_pushliteral(L, " ");
        }

        /* Function name */
        if (g_str_equal(ar.what, "main")) {
            lua_pushliteral(L, ANSI_COLOR_GRAY " in main chunk" ANSI_COLOR_RESET);
        } else {
            lua_pushliteral(L, ANSI_COLOR_GRAY " in function " ANSI_COLOR_RESET);
            lua_pushstring(L, ar.name ?: "[anonymous]");
        }

        if (level != max_level)
            lua_pushliteral(L, "\n");
    }

    lua_concat(L, lua_gettop(L) - top);
    return 1;
}

gint
luaH_dofunction_on_error(lua_State *L)
{
    lua_pushliteral(L, "\nTraceback:\n");
    luaH_traceback(L, 2);
    lua_concat(L, 3);
    return 1;
}

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
