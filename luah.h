/*
 * luah.h - Lua helper functions
 *
 * Copyright © 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright © 2008-2009 Julien Danjou <julien@danjou.info>
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

#ifndef LUAKIT_LUAH_H
#define LUAKIT_LUAH_H

#include "common/luah.h"

void luaH_init();
gboolean luaH_parserc(const gchar *, gboolean);
gint luaH_mtnext(lua_State *, gint);

void luaH_modifier_table_push(lua_State *, guint);
void luaH_keystr_push(lua_State *, guint);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
