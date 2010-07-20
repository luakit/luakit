/*
 * luaclass.h - useful functions for handling Lua classes
 *
 * Copyright (C) 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright (C) 2009 Julien Danjou <julien@danjou.info>
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

#ifndef LUAKIT_COMMON_LUACLASS_H
#define LUAKIT_COMMON_LUACLASS_H

#include <glib/gtree.h>

#include "common/lualib.h"
#include "common/signal.h"
#include "common/tokenize.h"

typedef struct     lua_class_property lua_class_property_t;
typedef GHashTable lua_class_property_array_t;

#define LUA_OBJECT_HEADER \
        signal_t *signals;

/* Generic type for all objects. All Lua objects can be casted
 * to this type. */
typedef struct {
    LUA_OBJECT_HEADER
} lua_object_t;

typedef lua_object_t *(*lua_class_allocator_t)(lua_State *);

typedef gint (*lua_class_propfunc_t)(lua_State *, lua_object_t *);

typedef struct {
    /** Class name */
    const gchar *name;
    /** Class signals */
    signal_t *signals;
    /** Allocator for creating new objects of that class */
    lua_class_allocator_t allocator;
    /** Class properties */
    lua_class_property_array_t *properties;
    /** Function to call when a indexing an unknown property */
    lua_class_propfunc_t index_miss_property;
    /** Function to call when a indexing an unknown property */
    lua_class_propfunc_t newindex_miss_property;
} lua_class_t;

const gchar *luaH_typename(lua_State *, gint);
lua_class_t *luaH_class_get(lua_State *, gint);

void luaH_class_add_signal(lua_State *, lua_class_t *, const gchar *, gint);
void luaH_class_remove_signal(lua_State *, lua_class_t *, const gchar *, gint);
void luaH_class_emit_signal(lua_State *, lua_class_t *, const gchar *, gint);

void luaH_openlib(lua_State *, const gchar *, const struct luaL_reg[], const struct luaL_reg[]);
void luaH_class_setup(lua_State *, lua_class_t *, const gchar *, lua_class_allocator_t,
                      lua_class_propfunc_t, lua_class_propfunc_t,
                      const struct luaL_reg[], const struct luaL_reg[]);

void luaH_class_add_property(lua_class_t *, luakit_token_t token,
        lua_class_propfunc_t, lua_class_propfunc_t, lua_class_propfunc_t);

gint luaH_usemetatable(lua_State *,  gint, gint);
gint luaH_class_index(lua_State *);
gint luaH_class_newindex(lua_State *);
gint luaH_class_new(lua_State *, lua_class_t *);

gpointer luaH_checkudata(lua_State *, gint, lua_class_t *);
gpointer luaH_toudata(lua_State *L, gint ud, lua_class_t *);

static inline gpointer
luaH_checkudataornil(lua_State *L, gint udx, lua_class_t *class) {
    if(lua_isnil(L, udx))
        return NULL;
    return luaH_checkudata(L, udx, class);
}

#define LUA_CLASS_FUNCS(prefix, lua_class) \
    static inline gint                                                         \
    luaH_##prefix##_class_add_signal(lua_State *L) {                           \
        luaH_class_add_signal(L, &(lua_class), luaL_checkstring(L, 1), 2);     \
        return 0;                                                              \
    }                                                                          \
                                                                               \
    static inline gint                                                         \
    luaH_##prefix##_class_remove_signal(lua_State *L) {                        \
        luaH_class_remove_signal(L, &(lua_class),                              \
                                 luaL_checkstring(L, 1), 2);                   \
        return 0;                                                              \
    }                                                                          \
                                                                               \
    static inline gint                                                         \
    luaH_##prefix##_class_emit_signal(lua_State *L) {                          \
        luaH_class_emit_signal(L, &(lua_class), luaL_checkstring(L, 1),        \
                              lua_gettop(L) - 1);                              \
        return 0;                                                              \
    }

#define LUA_CLASS_METHODS(class) \
    { "add_signal", luaH_##class##_class_add_signal }, \
    { "remove_signal", luaH_##class##_class_remove_signal }, \
    { "emit_signal", luaH_##class##_class_emit_signal },

#define LUA_CLASS_META \
    { "__index", luaH_class_index }, \
    { "__newindex", luaH_class_newindex },

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
