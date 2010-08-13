/*
 * luah.h - Lua helper functions
 *
 * Copyright (C) 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright (C) 2008-2009 Julien Danjou <julien@danjou.info>
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

#ifndef LUAKIT_LUA_H
#define LUAKIT_LUA_H

#include <lua.h>
#include "globalconf.h"
#include "common/luaobject.h"
#include "common/lualib.h"

#define luaH_deprecate(L, repl) \
    do { \
        luaH_warn(L, "%s: This function is deprecated and will be removed, see %s", \
                  __FUNCTION__, repl); \
        lua_pushlstring(L, __FUNCTION__, sizeof(__FUNCTION__)); \
        signal_object_emit(L, &globalconf.signals, "debug::deprecation", 1); \
    } while(0)

static inline gboolean
luaH_checkboolean(lua_State *L, gint n) {
    if(!lua_isboolean(L, n))
        luaL_typerror(L, n, "boolean");
    return lua_toboolean(L, n);
}

static inline gboolean
luaH_optboolean(lua_State *L, gint idx, gboolean def) {
    return luaL_opt(L, luaH_checkboolean, idx, def);
}

static inline lua_Number
luaH_getopt_number(lua_State *L, gint idx, const gchar *name, lua_Number def) {
    lua_getfield(L, idx, name);
    if (lua_isnil(L, -1) || lua_isnumber(L, -1))
        def = luaL_optnumber(L, -1, def);
    lua_pop(L, 1);
    return def;
}

static inline const gchar *
luaH_getopt_lstring(lua_State *L, gint idx, const gchar *name, const gchar *def, size_t *len) {
    lua_getfield(L, idx, name);
    const gchar *s = luaL_optlstring(L, -1, def, len);
    lua_pop(L, 1);
    return s;
}

static inline gboolean
luaH_getopt_boolean(lua_State *L, gint idx, const gchar *name, gboolean def) {
    lua_getfield(L, idx, name);
    gboolean b = luaH_optboolean(L, -1, def);
    lua_pop(L, 1);
    return b;
}

/* Register an Lua object.
 * \param L The Lua stack.
 * \param idx Index of the object in the stack.
 * \param ref A gint address: it will be filled with the gint
 * registered. If the address points to an already registered object, it will
 * be unregistered.
 * \return Always 0.
 */
static inline gint
luaH_register(lua_State *L, gint idx, gint *ref) {
    lua_pushvalue(L, idx);
    if(*ref != LUA_REFNIL)
        luaL_unref(L, LUA_REGISTRYINDEX, *ref);
    *ref = luaL_ref(L, LUA_REGISTRYINDEX);
    return 0;
}

/* Unregister a Lua object.
 * \param L The Lua stack.
 * \param ref A reference to an Lua object.
 */
static inline void
luaH_unregister(lua_State *L, gint *ref) {
    luaL_unref(L, LUA_REGISTRYINDEX, *ref);
    *ref = LUA_REFNIL;
}

/* Register a function.
 * \param L The Lua stack.
 * \param idx Index of the function in the stack.
 * \param fct A gint address: it will be filled with the gint
 * registered. If the address points to an already registered function, it will
 * be unregistered.
 * \return luaH_register value.
 */
static inline gint
luaH_registerfct(lua_State *L, gint idx, gint *fct) {
    luaH_checkfunction(L, idx);
    return luaH_register(L, idx, fct);
}

/* Grab a function from the registry and execute it.
 * \param L The Lua stack.
 * \param ref The function reference.
 * \param nargs The number of arguments for the Lua function.
 * \param nret The number of returned value from the Lua function.
 * \return True on no error, false otherwise.
 */
static inline gboolean
luaH_dofunction_from_registry(lua_State *L, gint ref, gint nargs, gint nret) {
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
    return luaH_dofunction(L, nargs, nret);
}

/* Print a warning about some Lua code.
 * This is less mean than luaL_error() which setjmp via lua_error() and kills
 * everything. This only warn, it's up to you to then do what's should be done.
 * \param L The Lua VM state.
 * \param fmt The warning message.
 */
static inline void __attribute__ ((format(printf, 2, 3)))
luaH_warn(lua_State *L, const gchar *fmt, ...) {
    va_list ap;
    luaL_where(L, 1);
    fprintf(stderr, "%sW: ", lua_tostring(L, -1));
    lua_pop(L, 1);
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fprintf(stderr, "\n");
}

void luaH_init();
gboolean luaH_parserc(const gchar *, gboolean);
gboolean luaH_hasitem(lua_State *, gconstpointer);
gint luaH_next(lua_State *, gint);
gboolean luaH_isloop(lua_State *, gint);

gint luaH_class_index_miss_property(lua_State *, lua_object_t *);
gint luaH_class_newindex_miss_property(lua_State *, lua_object_t *);
void luaH_modifier_table_push(lua_State *, guint);
void luaH_keystr_push(lua_State *, guint);

#endif
// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
