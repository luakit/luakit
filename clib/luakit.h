/*
 * clib/luakit.h - Generic functions for Lua scripts
 *
 * Copyright © 2011 Mason Larobina <mason.larobina@gmail.com>
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

#ifndef LUAKIT_CLIB_LUAKIT_H
#define LUAKIT_CLIB_LUAKIT_H

#include "common/luaclass.h"
#include "common/ipc.h"

#include <lua.h>

void luakit_lib_setup(lua_State *L);
void luaH_register_functions_on_endpoint(ipc_endpoint_t *ipc, lua_State *L);
lua_class_t * luakit_lib_get_luakit_class(void);
gint luaH_class_index_miss_property(lua_State *, lua_object_t *);
gint luaH_class_newindex_miss_property(lua_State *, lua_object_t *);

/* Referenced from deprecated webview:allow_certificate() */
gint luaH_luakit_allow_certificate(lua_State *L);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
