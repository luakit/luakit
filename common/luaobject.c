/*
 * luaobject.c - useful functions for handling Lua objects
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

#include "common/luaobject.h"

/* Setup the object system at startup. */
void
luaH_object_setup(lua_State *L) {
    /* Push identification string */
    lua_pushliteral(L, LUAKIT_OBJECT_REGISTRY_KEY);
    /* Create an empty table */
    lua_newtable(L);
    /* Create an empty metatable */
    lua_newtable(L);
    /* Set this empty table as the registry metatable.
     * It's used to store the number of reference on stored objects. */
    lua_setmetatable(L, -2);
    /* Register table inside registry */
    lua_rawset(L, LUA_REGISTRYINDEX);
}

/* Increment a object reference in its store table.
 * Removes the referenced object from the stack.
 * `tud` is the table index on the stack.
 * `oud` is the object index on the stack.
 * Returns a pointer to the object. */
gpointer
luaH_object_incref(lua_State *L, gint tud, gint oud) {
    /* Get pointer value of the item */
    gpointer p = (gpointer) lua_topointer(L, oud);

    /* Not reference able. */
    if(!p) {
        lua_remove(L, oud);
        return NULL;
    }

    /* Push the pointer (key) */
    lua_pushlightuserdata(L, p);
    /* Push the data (value) */
    lua_pushvalue(L, oud < 0 ? oud - 1 : oud);
    /* table.lightudata = data */
    lua_rawset(L, tud < 0 ? tud - 2 : tud);

    /* refcount++ */

    /* Get the metatable */
    lua_getmetatable(L, tud);
    /* Push the pointer (key) */
    lua_pushlightuserdata(L, p);
    /* Get the number of references */
    lua_rawget(L, -2);
    /* Get the number of references and increment it */
    gint count = lua_tonumber(L, -1) + 1;
    lua_pop(L, 1);
    /* Push the pointer (key) */
    lua_pushlightuserdata(L, p);
    /* Push count (value) */
    lua_pushinteger(L, count);
    /* Set metatable[pointer] = count */
    lua_rawset(L, -3);
    /* Pop metatable */
    lua_pop(L, 1);

    /* Remove referenced item */
    lua_remove(L, oud);

    return p;
}

/** Decrement a object reference in its store table.
 * `tud` is the table index on the stack.
 * `oud` is the object index on the stack.
 * Returns a pointer to the object.
 */
void
luaH_object_decref(lua_State *L, gint tud, gpointer p) {
    if(!p)
        return;

    /* First, refcount-- */
    /* Get the metatable */
    lua_getmetatable(L, tud);
    /* Push the pointer (key) */
    lua_pushlightuserdata(L, p);
    /* Get the number of references */
    lua_rawget(L, -2);
    /* Get the number of references and decrement it */
    gint count = lua_tonumber(L, -1) - 1;
    lua_pop(L, 1);
    /* Push the pointer (key) */
    lua_pushlightuserdata(L, p);
    /* Hasn't the ref reached 0? */
    if(count)
        lua_pushinteger(L, count);
    else
        /* Yup, delete it, set nil as value */
        lua_pushnil(L);
    /* Set meta[pointer] = count/nil */
    lua_rawset(L, -3);
    /* Pop metatable */
    lua_pop(L, 1);

    /* Wait, no more ref? */
    if(!count)
    {
        /* Yes? So remove it from table */
        lua_pushlightuserdata(L, p);
        /* Push nil as value */
        lua_pushnil(L);
        /* table[pointer] = nil */
        lua_rawset(L, tud < 0 ? tud - 2 : tud);
    }
}

gint
luaH_settype(lua_State *L, lua_class_t *lua_class) {
    lua_pushlightuserdata(L, lua_class);
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_setmetatable(L, -2);
    return 1;
}

/* Add a signal to an object.
 * `oud` is the object index on the stack.
 * `name` is the name of the signal.
 * `ud` is the index of function to call when signal is emitted. */
void
luaH_object_add_signal(lua_State *L, gint oud,
        const gchar *name, gint ud) {
    luaH_checkfunction(L, ud);
    lua_object_t *obj = lua_touserdata(L, oud);
    signal_add(obj->signals, name, luaH_object_ref_item(L, oud, ud));
}

/* Remove a signal to an object.
 * `oud` is the object index on the stack.
 * `name` is the name of the signal.
 * `ud` is the index of function to call when signal is emitted.
 */
void
luaH_object_remove_signal(lua_State *L, gint oud,
        const gchar *name, gint ud) {
    luaH_checkfunction(L, ud);
    lua_object_t *obj = lua_touserdata(L, oud);
    gpointer ref = (gpointer) lua_topointer(L, ud);
    signal_remove(obj->signals, name, ref);
    luaH_object_unref_item(L, oud, ref);
    lua_remove(L, ud);
}

/* Emit a signal from a signals array and return the results of the first
 * handler that returns something.
 * `signals` is the signals array.
 * `name` is the name of the signal.
 * `nargs` is the number of arguments to pass to the called functions.
 * `nret` is the number of return values this function pushes onto the stack.
 * A positive number means that any missing values will be padded with nil
 * and any superfluous values will be removed.
 * LUA_MULTRET means that any number of values is returned without any
 * adjustment.
 * 0 means that all return values are removed and that ALL handler functions are
 * executed.
 * Returns the number of return values pushed onto the stack. */
gint
signal_object_emit(lua_State *L, signal_t *signals,
        const gchar *name, gint nargs, gint nret) {

    signal_array_t *sigfuncs = signal_lookup(signals, name);
    debug("emitting \"%s\" with %d args and %d nret", name, nargs, nret);
    if(sigfuncs) {
        gint nbfunc = sigfuncs->len;
        luaL_checkstack(L, lua_gettop(L) + nbfunc + nargs + 1,
                "too much signal");
        /* Push all functions and then execute, because this list can change
         * while executing funcs. */
        for(gint i = 0; i < nbfunc; i++) {
            luaH_object_push(L, sigfuncs->pdata[i]);
        }

        for(gint i = 0; i < nbfunc; i++) {
            gint stacksize = lua_gettop(L);
            /* push all args */
            for(gint j = 0; j < nargs; j++)
                lua_pushvalue(L, - nargs - nbfunc + i);
            /* push first function */
            lua_pushvalue(L, - nargs - nbfunc + i);
            /* remove this first function */
            lua_remove(L, - nargs - nbfunc - 1 + i);
            luaH_dofunction(L, nargs, LUA_MULTRET);
            gint ret = lua_gettop(L) - stacksize + 1;

            /* Note that only if nret && ret will the signal execution stop */
            if (nret && ret) {
                /* remove all args and functions */
                for (gint j = 0; j < nargs + nbfunc - i - 1; j++) {
                    lua_remove(L, - ret - 1);
                }

                /* Adjust the number of results to match nret */
                if (nret != LUA_MULTRET && ret != nret) {
                    /* Pad with nils */
                    for (; ret < nret; ret++)
                        lua_pushnil(L);
                    /* Or truncate stack */
                    if (ret > nret) {
                        lua_pop(L, ret - nret);
                        ret = nret;
                    }
                }

                /* Return the number of returned arguments */
                return ret;
            } else if (nret == 0) {
                /* ignore all return values */
                lua_pop(L, ret);
            }
        }
    }
    /* remove args */
    lua_pop(L, nargs);
    return 0;
}

/* Emit a signal to an object.
 * `oud` is the object index on the stack.
 * `name` is the name of the signal.
 * `nargs` is the number of arguments to pass to the called functions.
 * `nret` is the number of return values this function pushes onto the stack.
 * A positive number means that any missing values will be padded with nil
 * and any superfluous values will be removed.
 * LUA_MULTRET means that any number of values is returned without any
 * adjustment.
 * 0 means that all return values are removed and that ALL handler functions are
 * executed.
 * Returns the number of return values pushed onto the stack. */
gint
luaH_object_emit_signal(lua_State *L, gint oud,
        const gchar *name, gint nargs, gint nret) {
    gint ret, top, bot = lua_gettop(L) - nargs + 1;
    gint oud_abs = luaH_absindex(L, oud);
    lua_object_t *obj = lua_touserdata(L, oud);
    debug("emitting \"%s\" on %p with %d args and %d nret", name, obj, nargs, nret);
    if(!obj)
        luaL_error(L, "trying to emit signal on non-object");
    signal_array_t *sigfuncs = signal_lookup(obj->signals, name);
    if(sigfuncs) {
        guint nbfunc = sigfuncs->len;
        luaL_checkstack(L, lua_gettop(L) + nbfunc + nargs + 2, "too much signal");
        /* Push all functions and then execute, because this list can change
         * while executing funcs. */
        for(guint i = 0; i < nbfunc; i++)
            luaH_object_push_item(L, oud_abs, sigfuncs->pdata[i]);

        for(guint i = 0; i < nbfunc; i++) {
            /* push object */
            lua_pushvalue(L, oud_abs);
            /* push all args */
            for(gint j = 0; j < nargs; j++)
                lua_pushvalue(L, - nargs - nbfunc - 1 + i);
            /* push first function */
            lua_pushvalue(L, - nargs - nbfunc - 1 + i);
            /* remove this first function */
            lua_remove(L, - nargs - nbfunc - 2 + i);
            top = lua_gettop(L) - 2 - nargs;
            luaH_dofunction(L, nargs + 1, LUA_MULTRET);
            ret = lua_gettop(L) - top;

            /* Note that only if nret && ret will the signal execution stop */
            if (nret && ret) {
                /* Adjust the number of results to match nret (including 0) */
                if (nret != LUA_MULTRET && ret != nret) {
                    /* Pad with nils */
                    for (; ret < nret; ret++)
                        lua_pushnil(L);
                    /* Or truncate stack */
                    if (ret > nret) {
                        lua_pop(L, ret - nret);
                        ret = nret;
                    }
                }
                /* Remove all signal functions and args from the stack */
                for (gint i = bot; i <= top; i++)
                    lua_remove(L, bot);
                /* Return the number of returned arguments */
                return ret;
            } else if (nret == 0) {
                /* ignore all return values */
                lua_pop(L, ret);
            }
        }
    }
    lua_pop(L, nargs);
    return 0;
}

gint
luaH_object_add_signal_simple(lua_State *L) {
    luaH_object_add_signal(L, 1, luaL_checkstring(L, 2), 3);
    return 0;
}

gint
luaH_object_remove_signal_simple(lua_State *L) {
    luaH_object_remove_signal(L, 1, luaL_checkstring(L, 2), 3);
    return 0;
}

gint
luaH_object_emit_signal_simple(lua_State *L) {
    return luaH_object_emit_signal(L, 1, luaL_checkstring(L, 2), lua_gettop(L) - 2, LUA_MULTRET);
}

gint
luaH_object_tostring(lua_State *L) {
    lua_class_t *lua_class = luaH_class_get(L, 1);
    lua_pushfstring(L, "%s: %p", lua_class->name, luaH_checkudata(L, 1, lua_class));
    return 1;
}

/** Garbage collect a Lua object.
 * \param L The Lua VM state.
 * \return The number of elements pushed on stack.
 */
gint
luaH_object_gc(lua_State *L) {
    lua_object_t *item = lua_touserdata(L, 1);
    if (item->signals)
        signal_destroy(item->signals);
    return 0;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
