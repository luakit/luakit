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

#ifndef LUAKIT_COMMON_LUAUNIQ_H
#define LUAKIT_COMMON_LUAUNIQ_H

#include <glib.h>
#include <lua.h>

/* Registry system for unique Lua objects.
 * In contrast to the luaobject system, useful when a unique Lua instance is
 * owned by a C object, this system should be used when the C instance lifetime
 * depends on the Lua instance lifetime.
 */

void luaH_uniq_setup(lua_State *L, const gchar *reg, const gchar *mode);
int luaH_uniq_add(lua_State *L, const gchar *reg, int k, int oud);
int luaH_uniq_add_ptr(lua_State *L, const gchar *reg, gpointer key, int oud);
int luaH_uniq_get(lua_State *L, const gchar *reg, int k);
int luaH_uniq_get_ptr(lua_State *L, const gchar *reg, gpointer key);
void luaH_uniq_del(lua_State *L, const gchar *reg, int k);
void luaH_uniq_del_ptr(lua_State *L, const gchar *reg, gpointer key);

#endif /* end of include guard: LUAKIT_COMMON_LUAUNIQ_H */

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
