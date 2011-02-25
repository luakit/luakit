/*
 * timer.c - Simple timer class
 *
 * Copyright © 2009 Julien Danjou <julien@danjou.info>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 */

#include <glib.h>
#include <stdbool.h>

#include "globalconf.h"
#include "luah.h"
#include "classes/timer.h"
#include "common/luaobject.h"

typedef struct
{
    LUA_OBJECT_HEADER
    gpointer ref;
    int timer_id;
    int interval;
} ltimer_t;

/* Glib returns a uint, so a negative number should be safe. */
#define TIMER_STOPPED -1
/* The field in which to store the function that handles the timeout. */
#define TIMER_FUNC_FIELD "func"
/* The field in which to store the interval of the timeout. */
#define TIMER_INTERVAL_FIELD "interval"

static lua_class_t timer_class;
LUA_OBJECT_FUNCS(timer_class, ltimer_t, timer)

/* Unrefs and resets the given timer and destroys its event source.
 * \param L The Lua VM state.
 * \param timer The timer structure.
 */
static void
luaH_timer_destroy(lua_State *L, ltimer_t *timer) {
    GSource *source = g_main_context_find_source_by_id(NULL, timer->timer_id);
    if (source != NULL) {
        g_source_destroy(source);
    }
    luaH_object_unref(L, timer->ref); // now the timer may be garbage collected
    timer->ref = NULL;
    timer->timer_id = TIMER_STOPPED;
}

static gboolean
timer_handle_timeout(gpointer data)
{
    ltimer_t *timer = (ltimer_t *) data;
    luaH_object_push(globalconf.L, timer->ref);
    luaH_object_emit_signal(globalconf.L, -1, "timeout", 1, 0);
    return TRUE;
}

static int
luaH_timer_new(lua_State *L)
{
    luaH_class_new(L, &timer_class);
    ltimer_t *timer = luaH_checkudata(L, -1, &timer_class);
    timer->ref = NULL;
    timer->timer_id = TIMER_STOPPED;
    return 1;
}

static int
luaH_timer_start(lua_State *L)
{
    ltimer_t *timer = luaH_checkudata(L, 1, &timer_class);
    // get interval
    lua_getfield(L, -1, TIMER_INTERVAL_FIELD);
    int millis = luaL_checkinteger(L, -1);
    timer->ref = luaH_object_ref(L, 1); // ensure that timers don't get collected while running
    if (timer->timer_id == TIMER_STOPPED) {
        timer->timer_id = g_timeout_add(millis, timer_handle_timeout, timer);
    } else {
        luaH_warn(L, "timer already started. Cannot start a timer twice");
    }
    return 0;
}

static int
luaH_timer_stop(lua_State *L)
{
    ltimer_t *timer = luaH_checkudata(L, 1, &timer_class);
    if (timer->timer_id == TIMER_STOPPED) {
        luaH_warn(L, "timer already stopped. Cannot stop a timer twice");
    } else {
        luaH_timer_destroy(L, timer);
    }
    return 0;
}

static int
luaH_timer_set_interval(lua_State *L, ltimer_t *timer)
{
    int interval = luaL_checkinteger(L, -1);
    timer->interval = interval;
    return 0;
}

static int
luaH_timer_get_interval(lua_State *L, ltimer_t *timer)
{
    lua_pushinteger(L, timer->interval);
    return 1;
}

static int
luaH_timer_get_started(lua_State *L, ltimer_t *timer)
{
    bool started = (timer->timer_id != TIMER_STOPPED);
    lua_pushboolean(L, started);
    return 1;
}

void
timer_class_setup(lua_State *L)
{
    static const struct luaL_reg timer_methods[] =
    {
        LUA_CLASS_METHODS(timer)
        { "__call", luaH_timer_new },
        { NULL, NULL }
    };

    static const struct luaL_reg timer_meta[] =
    {
        LUA_OBJECT_META(timer)
        LUA_CLASS_META
        { "start", luaH_timer_start },
        { "stop", luaH_timer_stop },
        { NULL, NULL },
    };

    luaH_class_setup(L, &timer_class, "timer",
                     (lua_class_allocator_t) timer_new,
                     luaH_class_index_miss_property, luaH_class_newindex_miss_property,
                     timer_methods, timer_meta);
    luaH_class_add_property(&timer_class, L_TK_INTERVAL,
                            (lua_class_propfunc_t) luaH_timer_set_interval,
                            (lua_class_propfunc_t) luaH_timer_get_interval,
                            (lua_class_propfunc_t) luaH_timer_set_interval);
    luaH_class_add_property(&timer_class, L_TK_STARTED,
                            NULL,
                            (lua_class_propfunc_t) luaH_timer_get_started,
                            NULL);
}

// vim: filetype=c:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
