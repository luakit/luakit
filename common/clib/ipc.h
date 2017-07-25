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

#ifndef LUAKIT_COMMON_CLIB_IPC_H
#define LUAKIT_COMMON_CLIB_IPC_H

#include <lua.h>
#include <glib.h>

#include "common/util.h"
#include "common/luaclass.h"
#include "common/luaobject.h"

typedef struct _ipc_channel_t {
    LUA_OBJECT_HEADER
    char *name;
} ipc_channel_t;

ipc_channel_t *luaH_check_ipc_channel(lua_State *L, gint idx);
gint luaH_ipc_channel_new(lua_State *L);
gint ipc_channel_send(lua_State *L);
void ipc_channel_recv(lua_State *L, const gchar *arg, guint arglen);
void ipc_channel_set_module(lua_State *L, const gchar *module_name);
void ipc_channel_class_setup(lua_State *);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
