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

#ifndef LUAKIT_COMMON_LUAUTIL_H
#define LUAKIT_COMMON_LUAUTIL_H

#include <lua.h>
#include <glib.h>

gint luaH_traceback(lua_State *L, lua_State *T, gint level);
gint luaH_dofunction_on_error(lua_State *L);
void luaH_add_paths(lua_State *L, const gchar *config_dir);
gint luaH_push_gerror(lua_State *L, GError *error);
gint luaH_push_strv(lua_State *L, const gchar * const *strv);
const gchar ** luaH_checkstrv(lua_State *L, gint idx);

#endif /* end of include guard: LUAKIT_COMMON_LUAUTIL_H */

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
