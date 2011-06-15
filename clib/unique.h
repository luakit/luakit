/*
 * clib/unique.c - libunique bindings for writing single instance
 * applications
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

#if WITH_UNIQUE

#ifndef LUAKIT_CLIB_UNIQUE_H
#define LUAKIT_CLIB_UNIQUE_H

#include <lua.h>

void unique_lib_setup(lua_State*);

#endif /* #if LUAKIT_CLIB_UNIQUE_H */
#endif /* #if WITH_UNIQUE */

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
