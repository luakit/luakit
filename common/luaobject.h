/*
 * luaobject.h - useful functions for handling Lua objects
 *
 * Copyright © 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright © 2009 Julien Danjou <julien@danjou.info>
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

#ifndef LUAKIT_COMMON_LUAOBJECT_H
#define LUAKIT_COMMON_LUAOBJECT_H

#include "common/luaclass.h"
#include "common/lualib.h"
#include "common/signal.h"
#include "globalconf.h"

gint luaH_settype(lua_State *L, lua_class_t *lua_class);
void luaH_object_setup(lua_State *L);
gpointer luaH_object_incref(lua_State *L, gint tud, gint oud);
void luaH_object_decref(lua_State *L, gint tud, gpointer oud);

/* Store an item in the environment table of an object.
 * Removes the stored object from the stack.
 * `ud` is the index of the object on the stack.
 * `iud` is the index of the item on the stack.
 * Return the item reference. */
static inline gpointer
luaH_object_ref_item(lua_State *L, gint ud, gint iud) {
    /* Get the env table from the object */
    lua_getfenv(L, ud);
    gpointer p = luaH_object_incref(L, -1, iud < 0 ? iud - 1 : iud);
    /* Remove env table */
    lua_pop(L, 1);
    return p;
}

/* Unref an item from the environment table of an object.
 * `ud` is the index of the object on the stack.
 * `p` is the item. */
static inline void
luaH_object_unref_item(lua_State *L, gint ud, gpointer p) {
    /* Get the env table from the object */
    lua_getfenv(L, ud);
    /* Decrement */
    luaH_object_decref(L, -1, p);
    /* Remove env table */
    lua_pop(L, 1);
}

/* Push an object item on the stack.
 * `ud` is the object index on the stack.
 * `p` is the item pointer.
 * Returns the number of element pushed on stack. */
static inline gint
luaH_object_push_item(lua_State *L, gint ud, gpointer p) {
    /* Get env table of the object */
    lua_getfenv(L, ud);
    /* Push key */
    lua_pushlightuserdata(L, p);
    /* Get env.pointer */
    lua_rawget(L, -2);
    /* Remove env table */
    lua_remove(L, -2);
    return 1;
}

static inline void
luaH_object_registry_push(lua_State *L) {
    lua_pushliteral(L, LUAKIT_OBJECT_REGISTRY_KEY);
    lua_rawget(L, LUA_REGISTRYINDEX);
}

/* Reference an object and return a pointer to it. That only works with
 * userdata, table, thread or function.
 * Removes the referenced object from the stack.
 * `oud` is the object index on the stack.
 * Returns the object reference, or NULL if not referenceable. */
static inline gpointer
luaH_object_ref(lua_State *L, gint oud) {
    luaH_object_registry_push(L);
    gpointer p = luaH_object_incref(L, -1, oud < 0 ? oud - 1 : oud);
    lua_pop(L, 1);
    return p;
}

/* Reference an object and return a pointer to it checking its type. That only
 * works with userdata.
 * `oud` is the object index on the stack.
 * `class` is the class of object expected
 * Return the object reference, or NULL if not referenceable. */
static inline gpointer
luaH_object_ref_class(lua_State *L, gint oud, lua_class_t *class) {
    luaH_checkudata(L, oud, class);
    return luaH_object_ref(L, oud);
}

/* Unreference an object and return a pointer to it. That only works with
 * userdata, table, thread or function.
 * `oud` is the object index on the stack. */
static inline void
luaH_object_unref(lua_State *L, gpointer p) {
    luaH_object_registry_push(L);
    luaH_object_decref(L, -1, p);
    lua_pop(L, 1);
}

/* Push a referenced object onto the stack.
 * `p` is the object to push.
 * Returns is the number of element pushed on stack.
 */
static inline gint
luaH_object_push(lua_State *L, gpointer p) {
    luaH_object_registry_push(L);
    lua_pushlightuserdata(L, p);
    lua_rawget(L, -2);
    lua_remove(L, -2);
    return 1;
}

gint signal_object_emit(lua_State *, signal_t *signals,
        const gchar *name, gint nargs, gint nret);
void luaH_object_add_signal(lua_State *L, gint oud,
        const gchar *name, gint ud);
void luaH_object_remove_signal(lua_State *L, gint oud,
        const gchar *name , gint ud);
gint luaH_object_emit_signal(lua_State *L, gint oud,
        const gchar *name, gint nargs, gint nret);

static inline gint
luaH_object_emit_property_signal(lua_State *L, gint oud)
{
    size_t len;
    gchar *signame = g_strdup_printf("property::%s",
        luaL_checklstring(L, oud + 1, &len));
    luaH_object_emit_signal(L, oud, signame, 0, 0);
    g_free(signame);
    return 0;
}

gint luaH_object_add_signal_simple(lua_State *L);
gint luaH_object_remove_signal_simple(lua_State *L);
gint luaH_object_emit_signal_simple(lua_State *L);

#define LUA_OBJECT_FUNCS(lua_class, type, prefix)             \
    LUA_CLASS_FUNCS(prefix, lua_class)                        \
    static inline type *                                      \
    prefix##_new(lua_State *L) {                              \
        type *p = lua_newuserdata(L, sizeof(type));           \
        p_clear(p, 1);                                        \
        p->signals = signal_new();                            \
        luaH_settype(L, &(lua_class));                        \
        lua_newtable(L);                                      \
        lua_newtable(L);                                      \
        lua_setmetatable(L, -2);                              \
        lua_setfenv(L, -2);                                   \
        lua_pushvalue(L, -1);                                 \
        luaH_class_emit_signal(L, &(lua_class), "new", 1, 0); \
        return p;                                             \
    }

#define OBJECT_EXPORT_PROPERTY(pfx, type, field) \
    fieldtypeof(type, field)                     \
    pfx##_get_##field(type *object) {            \
        return object->field;                    \
    }

#define LUA_OBJECT_EXPORT_PROPERTY(pfx, type, field, pusher) \
    static gint                                              \
    luaH_##pfx##_get_##field(lua_State *L, type *object) {   \
        pusher(L, object->field);                            \
        return 1;                                            \
    }

gint luaH_object_tostring(lua_State *);
gint luaH_object_gc(lua_State *);

#define LUA_OBJECT_META(prefix)                            \
    { "__tostring", luaH_object_tostring },                \
    { "add_signal", luaH_object_add_signal_simple },       \
    { "remove_signal", luaH_object_remove_signal_simple }, \
    { "emit_signal", luaH_object_emit_signal_simple },

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
