/*
 * common/clib/msg.c - Lua logging interface
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

gpointer string_format_ref;

static gint
luaH_msg_warn(lua_State *L)
{
    gint nargs = lua_gettop(L);
    luaH_object_push(L, string_format_ref);
    lua_insert(L, 1);
    if (lua_pcall(L, nargs, 1, 0))
        return luaL_error(L, "failed to format message: %s", lua_tostring(L, -1));
    const gchar *msg = lua_tostring(L, -1);
    printf("%s\n", msg);
    return 0;
}

static gint
luaH_msg_info(lua_State *L)
{
    if (!globalconf.verbose)
        return 0;
        
    gint nargs = lua_gettop(L);
    luaH_object_push(L, string_format_ref);
    lua_insert(L, 1);
    if (lua_pcall(L, nargs, 1, 0))
        return luaL_error(L, "failed to format message: %s", lua_tostring(L, -1));
    const gchar *msg = lua_tostring(L, -1);
    printf("%s\n", msg);
    return 0;
}

/** Setup luakit module.
 *
 * \param L The Lua VM state.
 */
void
msg_lib_setup(lua_State *L)
{
    static const struct luaL_reg msg_lib[] =
    {
        { "info",              luaH_msg_info },
        { "warn",              luaH_msg_warn },
        { NULL,              NULL }
    };

    /* export luakit lib */
    luaH_openlib(L, "msg", msg_lib, msg_lib);

    /* Store ref to string.format() */
    lua_getglobal(L, "string");
    lua_getfield(L, -1, "format");
    string_format_ref = luaH_object_ref(L, -1);
    lua_pop(L, 1);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
