/*
 * tests/util.c - testing utility functions
 *
 * Copyright © 2017 Aidan Holm <aidanholm@gmail.com>
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

#include <errno.h>
#include <lauxlib.h>
#include <signal.h>
#include "common/util.h"
#include "common/lualib.h"

static int
l_make_tmp_dir(lua_State *L)
{
    const char *fmt = lua_isnil(L, 1) ? NULL : luaL_checkstring(L, 1);
    GError *error = NULL;
    char *dir = g_dir_make_tmp(fmt, &error);
    lua_pushstring(L, dir);
    g_free(dir);
    if (error) {
        lua_pushstring(L, error->message);
        g_error_free(error);
    }
    return error ? 2 : 1;
}

static int
l_spawn_async(lua_State *L)
{
    /* Convert the first argv table argument to a char** */
    luaH_checktable(L, 1);
    size_t n = lua_objlen(L, 1);
    if (n == 0)
        return luaL_error(L, "argv must be non-empty");
    GPtrArray *argv = g_ptr_array_sized_new(n + 1);
    for (size_t i = 1; i <= n; i++) {
        lua_rawgeti(L, 1, i);
        if (!lua_isstring(L, -1)) {
            g_ptr_array_free(argv, TRUE);
            return luaL_error(L, "non-string argv element #%u", i);
        }
        g_ptr_array_add(argv, (gpointer)lua_tostring(L, -1));
        lua_pop(L, 1);
    }
    g_ptr_array_add(argv, NULL);

    GSpawnFlags spawn_flags = G_SPAWN_SEARCH_PATH;
    GPid child_pid;
    GError *error = NULL;

    g_spawn_async(NULL, (gchar**)argv->pdata, NULL, spawn_flags, NULL, NULL,
            &child_pid, &error);
    g_ptr_array_free(argv, TRUE);

    if (!error)
        lua_pushnumber(L, child_pid);
    else {
        lua_pushnil(L);
        lua_pushstring(L, error->message);
        g_error_free(error);
    }
    return error ? 2 : 1;
}

static int
l_getenv(lua_State *L)
{
    lua_pushstring(L, g_getenv(luaL_checkstring(L, 1)));
    return 1;
}

static int
l_kill(lua_State *L)
{
    pid_t pid = luaL_checknumber(L, 1);
    int sig = luaL_optint(L, 2, SIGTERM);

    if (!kill(pid, sig))
        return 0;
    lua_pushstring(L, strerror(errno));
    return 1;
}

int
luaopen_tests_util(lua_State *L)
{
    static const struct luaL_Reg util [] = {
        {"make_tmp_dir", l_make_tmp_dir},
        {"spawn_async", l_spawn_async},
        {"getenv", l_getenv},
        {"kill", l_kill},
        {NULL, NULL},
    };
    luaL_openlib(L, "tests.util", util, 0);
    return 1;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
