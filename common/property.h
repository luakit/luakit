/*
 * common/property.h - GObject property set/get lua functions
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

#ifndef LUAKIT_COMMON_PROPERTY_H
#define LUAKIT_COMMON_PROPERTY_H

#include <lua.h>
#include <glib-object.h>

#include "common/tokenize.h"

typedef enum {
    BOOL,
    CHAR,
    DOUBLE,
    FLOAT,
    INT,
    URI,
} property_value_t;

typedef union {
    gchar *c;
    gboolean b;
    gdouble d;
    gfloat f;
    gint i;
} property_tmp_t;

typedef struct {
    luakit_token_t tok;
    const gchar *name;
    property_value_t type;
    gboolean writable;
} property_t;

gint luaH_gobject_index(lua_State *, property_t *, luakit_token_t, GObject *);
gboolean luaH_gobject_newindex(lua_State *, property_t *, luakit_token_t,
        gint, GObject *);

#endif
