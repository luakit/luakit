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

#include <lauxlib.h>
#include "common/util.h"

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

int
luaopen_tests_util(lua_State *L)
{
    static const struct luaL_reg util [] = {
        {"make_tmp_dir", l_make_tmp_dir},
        {NULL, NULL},
    };
    luaL_openlib(L, "tests.util", util, 0);
    return 1;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
