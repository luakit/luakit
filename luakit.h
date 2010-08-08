/*
 * luakit.h - luakit main functions
 *
 * Copyright (C) 2010 Mason Larobina <mason.larobina@gmail.com>
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

#ifndef LUAKIT_LUAKIT_H
#define LUAKIT_LUAKIT_H

#include <lua.h>
#include "common/signal.h"

typedef struct {
    /* Path to the config file */
    gchar *confpath;
    /* Lua VM state */
    lua_State *L;
    /* global signals */
    signal_t *signals;
} Luakit;

/* Global config/state object */
extern Luakit luakit;

#endif
// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
