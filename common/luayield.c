/*
 * common/luayield.c - Lua yield support
 *
 * Copyright © 2017 Aidan Holm <aidanholm@gmail.com>
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

#include "common/luayield.h"
#include "common/lualib.h"
#include "common/luaobject.h"

#include <glib.h>

static void *wrap_function_ref;
static void *yield_ref;
static void *unlock_ref;
static const char * sched_src =                                                                  \
                                                                                                 \
" local y = {}                                                                               \n" \
"                                                                                            \n" \
" local wrap_function = function (fn)                                                        \n" \
"     return function (...)                                                                  \n" \
"         assert(coroutine.running(), 'cannot call asynchronous function from main thread!') \n" \
"         y.yieldable = true                                                                 \n" \
"         local ret = {fn(...)}                                                              \n" \
"         y.yieldable = false                                                                \n" \
"         if y.yield then                                                                    \n" \
"             y.yield = false                                                                \n" \
"             y[coroutine.running()] = true                                                  \n" \
"             repeat                                                                         \n" \
"                 ret = {coroutine.yield()}                                                  \n" \
"             until not y[coroutine.running()]                                               \n" \
"         end                                                                                \n" \
"         return unpack(ret)                                                                 \n" \
"     end                                                                                    \n" \
" end                                                                                        \n" \
"                                                                                            \n" \
" local yield = function ()                                                                  \n" \
"     assert(y.yieldable, 'attempted to yield from unwrapped operation!')                    \n" \
"     y.yield = true                                                                         \n" \
" end                                                                                        \n" \
"                                                                                            \n" \
" local unlock = function ()                                                                 \n" \
"     y[coroutine.running()] = nil                                                           \n" \
" end                                                                                        \n" \
"                                                                                            \n" \
" return {                                                                                   \n" \
"     wrap_function = wrap_function,                                                         \n" \
"     yield = yield,                                                                         \n" \
"     unlock = unlock,                                                                       \n" \
" }                                                                                          \n" \
;

void
luaH_yield_setup(lua_State *L)
{
    gint top = lua_gettop(L);
    luaL_loadbuffer(L, sched_src, strlen(sched_src), "luakit_yield_handler");
    luaH_dofunction(L, 0, 1);
    lua_getfield(L, -1, "yield");
    yield_ref = luaH_object_ref(L, -1);
    lua_getfield(L, -1, "wrap_function");
    wrap_function_ref = luaH_object_ref(L, -1);
    lua_getfield(L, -1, "unlock");
    unlock_ref = luaH_object_ref(L, -1);
    lua_settop(L, top);
}

void
luaH_yield_wrap_function(lua_State *L)
{
    luaH_checkfunction(L, -1);
    luaH_object_push(L, wrap_function_ref);
    luaH_dofunction(L, 1, 1);
}

int
luaH_yield(lua_State *L)
{
    luaH_object_push(L, yield_ref);
    luaH_dofunction(L, 0, 0);
    return 0;
}

/** Continue a suspended Lua thread.
 * \param L The Lua stack.
 * \param nret The number of values to return to the suspended thread.
 * \return True on no error, false otherwise.
 */
gboolean
luaH_resume(lua_State *L, gint nret) {
    luaH_object_push(L, unlock_ref);
    luaH_dofunction(L, 0, 0);
    gint top = lua_gettop(L) - nret;
    gint ret = lua_resume(L, nret);
    if (ret == 0 || ret == LUA_YIELD)
        return TRUE;
    lua_pushcfunction(L, luaH_dofunction_on_error);
    lua_insert(L, -2);
    lua_call(L, 1, 1);
    error("%s", lua_tostring(L, -1));
    lua_settop(L, top);
    return FALSE;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
