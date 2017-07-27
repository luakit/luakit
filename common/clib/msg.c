/*
 * common/clib/msg.c - Lua logging interface
 *
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

#include "common/clib/msg.h"
#include "luah.h"

#include <stdlib.h>
#include <glib.h>
#include <gtk/gtk.h>
#include <sys/wait.h>
#include <time.h>
#include <webkit2/webkit2.h>

static gpointer string_format_ref;
static gpointer tostring_ref;

static const gchar *
luaH_msg_string_from_args(lua_State *L)
{
    gint nargs = lua_gettop(L);
    /* Pre-convert all non-numerical arguments to strings */
    for (gint i = 1; i <= nargs; ++i) {
        if (lua_type(L, i) != LUA_TNUMBER) {
            /* Convert to a string with tostring() ... */
            luaH_object_push(L, tostring_ref);
            lua_pushvalue(L, i);
            lua_pcall(L, 1, 1, 0);
            /* ... And replace the original value */
            lua_remove(L, i);
            lua_insert(L, i);
        }
    }
    luaH_object_push(L, string_format_ref);
    lua_insert(L, 1);
    if (lua_pcall(L, nargs, 1, 0))
        luaL_error(L, "failed to format message: %s", lua_tostring(L, -1));
    return lua_tostring(L, -1);
}

static gint
luaH_msg(lua_State *L, log_level_t lvl)
{
    lua_Debug ar;
    lua_getstack(L, 1, &ar);
    lua_getinfo(L, "Sln", &ar);
    /* Use .source if it's a file, since short_src is truncated for long paths */
    const char *src = ar.source[0] == '@' ? ar.source+1 : ar.short_src;
    _log(lvl, src, "%s", luaH_msg_string_from_args(L));
    return 0;
}

#define X(name) \
static gint \
luaH_msg_##name(lua_State *L) \
{ \
    return luaH_msg(L, LOG_LEVEL_##name); \
} \

LOG_LEVELS
#undef X

void
msg_lib_setup(lua_State *L)
{
    static const struct luaL_Reg msg_lib[] =
    {
#define X(name) \
        { #name, luaH_msg_##name },
        LOG_LEVELS
#undef X
        { NULL,              NULL }
    };

    /* export luakit lib */
    luaH_openlib(L, "msg", msg_lib, msg_lib);

    /* Store ref to string.format() */
    lua_getglobal(L, "string");
    lua_getfield(L, -1, "format");
    string_format_ref = luaH_object_ref(L, -1);
    lua_pop(L, 1);

    /* Store ref to tostring() */
    lua_getglobal(L, "tostring");
    tostring_ref = luaH_object_ref(L, -1);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
