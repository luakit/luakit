/*
 * common/clib/luakit.h - Generic functions for Lua scripts
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

#ifndef LUAKIT_COMMON_CLIB_LUAKIT_H
#define LUAKIT_COMMON_CLIB_LUAKIT_H

#include <lauxlib.h>
#include <lua.h>
#include <glib.h>

#define LUAKIT_LIB_COMMON_METHODS \
    { "time",        luaH_luakit_time        }, \
    { "uri_encode",  luaH_luakit_uri_encode  }, \
    { "uri_decode",  luaH_luakit_uri_decode  }, \
    { "idle_add",    luaH_luakit_idle_add    }, \
    { "idle_remove", luaH_luakit_idle_remove }, \

gint luaH_luakit_time(lua_State *L);
gint luaH_luakit_uri_encode(lua_State *L);
gint luaH_luakit_uri_decode(lua_State *L);
gint luaH_luakit_idle_add(lua_State *L);
gint luaH_luakit_idle_remove(lua_State *L);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
