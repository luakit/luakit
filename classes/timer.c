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

#include "classes/timer.h"
#include "common/luaobject.h"
#include "globalconf.h"
#include "luah.h"

#include <glib.h>

typedef struct {
    LUA_OBJECT_HEADER
    gpointer ref;
    int id;
    int interval;
} ltimer_t;

static lua_class_t timer_class;
LUA_OBJECT_FUNCS(timer_class, ltimer_t, timer)

#define TIMER_STOPPED -1

#define luaH_checktimer(L, idx) luaH_checkudata(L, idx, &(timer_class))

static void
luaH_timer_destroy(lua_State *L, ltimer_t *timer) {
    GSource *source = g_main_context_find_source_by_id(NULL, timer->id);
    if (source != NULL)
        g_source_destroy(source);

    /* allow timer to be garbage collected */
    luaH_object_unref(L, timer->ref);
    timer->ref = NULL;

    timer->id = TIMER_STOPPED;
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
    ltimer_t *timer = luaH_checktimer(L, -1);
    timer->id = TIMER_STOPPED;
    return 1;
}

static int
luaH_timer_start(lua_State *L)
{
    ltimer_t *timer = luaH_checktimer(L, 1);
    if (!timer->interval)
        luaL_error(L, "interval not set");

    if (timer->id == TIMER_STOPPED) {
        /* ensure timer isn't collected while running */
        timer->ref = luaH_object_ref(L, 1);
        timer->id = g_timeout_add(timer->interval, timer_handle_timeout, timer);
    } else
        luaH_warn(L, "timer already started");
    return 0;
}

static int
luaH_timer_stop(lua_State *L)
{
    ltimer_t *timer = luaH_checktimer(L, 1);
    if (timer->id == TIMER_STOPPED)
        luaH_warn(L, "timer already stopped");
    else
        luaH_timer_destroy(L, timer);
    return 0;
}

static int
luaH_timer_set_interval(lua_State *L, ltimer_t *timer)
{
    timer->interval = luaL_checkint(L, -1);
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
    lua_pushboolean(L, (timer->id != TIMER_STOPPED));
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

#undef luaH_checktimer

// vim: filetype=c:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
