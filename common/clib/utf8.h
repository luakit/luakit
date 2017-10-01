/*
 * common/clib/utf8.h - UTF8 class header
 *
 * Copyright © 2017 Dennis Hofheinz <github@kjdf.de>
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

#ifndef LUAKIT_COMMON_CLIB_UTF8_H
#define LUAKIT_COMMON_CLIB_UTF8_H

#include <lua.h>

void utf8_lib_setup(lua_State *);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
