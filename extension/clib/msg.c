/*
 * extension/clib/msg.c - Lua logging interface
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

#include "extension/clib/msg.h"
#include "common/clib/msg.h"

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
