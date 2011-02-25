/*
 * common/property.h - GObject property set/get lua functions
 *
 * Copyright (C) 2011 Mason Larobina <mason.larobina@gmail.com>
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

#include "luah.h"

typedef enum {
    BOOL,
    CHAR,
    INT,
    FLOAT,
    DOUBLE,
    URI,
} property_value_t;

typedef enum {
    SETTINGS,
    WEBKITVIEW,
    SESSION,
    COOKIEJAR,
} property_scope;

typedef union {
    gchar *c;
    gboolean b;
    gdouble d;
    gfloat f;
    gint i;
} property_tmp_value_t;

typedef struct {
    const gchar *name;
    property_value_t type;
    property_scope scope;
    gboolean writable;
    const gchar *signame;
} property_t;

GHashTable* hash_properties(property_t *properties);
gint luaH_get_property(lua_State *L, GHashTable *properties, gpointer obj, gint nidx);
gint luaH_set_property(lua_State *L, GHashTable *properties, gpointer obj, gint nidx, gint vidx);

#endif
