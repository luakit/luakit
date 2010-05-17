/*
 * window.h - window manager
 *
 * Copyright (C) 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright (C) 2007-2009 Julien Danjou <julien@danjou.info>
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

#include "luakit.h"
#include "luah.h"
#include "window.h"

LUA_OBJECT_FUNCS(window_class, window_t, window);

void
destroy_win_cb(window_t *w)
{
    if (w->win) {
        gtk_widget_destroy(w->win);
        w->win = NULL;
    }
}

static gint
luaH_window_gc(lua_State *L)
{
    window_t *w = luaH_checkudata(L, 1, &window_class);
    if (w->win)
        destroy_win_cb(w);

    return luaH_object_gc(L);
}

static gint
luaH_window_new(lua_State *L)
{
    luaH_class_new(L, &window_class);
    window_t *w = luaH_checkudata(L, -1, &window_class);

    /* save ref to the lua class instance */
    lua_pushvalue(L, -1);
    w->ref = luaH_object_ref_class(L, -1, &window_class);

    w->win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_wmclass(GTK_WINDOW(w->win), "luakit", "luakit");
    gtk_window_set_default_size(GTK_WINDOW(w->win), 800, 600);
    g_signal_connect(G_OBJECT(w->win), "destroy", G_CALLBACK(destroy_win_cb), w);

    /* show new window */
    gtk_widget_show(w->win);

    gtk_window_set_title(GTK_WINDOW(w->win), "luakit");

    luaH_object_emit_signal(L, -1, "init", 0);

    return 1;
}

static gint
luaH_window_index(lua_State *L)
{
    size_t len;
    const char *prop = luaL_checklstring(L, 2, &len);
    //luakit_token_t token = l_tokenize(prop, len);

    /* Try standard method */
    if(luaH_class_index(L))
        return 1;

    window_t *w = luaH_checkudata(L, 1, &window_class);
    debug("index %s on window at %p", prop, w);
    return 0;
}

static gint
luaH_window_newindex(lua_State *L)
{
    size_t len;
    const char *prop = luaL_checklstring(L, 2, &len);
    //luakit_token_t token = l_tokenize(prop, len);

    /* Try standard method */
    luaH_class_newindex(L);

    window_t *w = luaH_checkudata(L, 1, &window_class);
    debug("newindex %s on window at %p", prop, w);
    return 0;
}

static gint
luaH_window_set_title(lua_State *L, window_t *w)
{
    size_t len;
    const gchar *title = luaL_checklstring(L, 3, &len);
    gtk_window_set_title(GTK_WINDOW(w->win), g_strdup(title));
    luaH_object_emit_signal(L, 1, "property::title", 0);
    return 0;
}

static gint
luaH_window_get_title(lua_State *L, window_t *w)
{
    lua_pushstring(L, w->title ? w->title : "");
    return 1;
}

static gint
luaH_window_set_child(lua_State *L)
{
    window_t *w = luaH_checkudata(L, 1, &window_class);

    /* Check new child */
    widget_t *child = luaH_checkudata(L, 2, &widget_class);
    // TODO Should I steal children from their parents?
    if (child->parent || child->window)
        luaL_error(L, "child widget already has a parent");

    /* Detach old child widget */
    if (w->child) {
        luaH_object_push(L, w->child->ref);
        w->child->window = NULL;
        w->child = NULL;
        luaH_object_emit_signal(L, 1, "remove", 1);
        //TODO Should I raise a "detached" signal on the widget?
    }

    debug("child gtk widget %p", child->widget);
    gtk_container_add(GTK_CONTAINER(w->win), GTK_WIDGET(child->widget));
    child->window = w;
    luaH_object_push(L, child->ref);
    luaH_object_emit_signal(L, 1, "add", 1);
    return 0;
}

static gint
luaH_window_get_child(lua_State *L, window_t *w)
{
    if (!w->child)
        return 0;

    luaH_object_push(L, w->child);
    return 1;
}

void
window_class_setup(lua_State *L)
{
    static const struct luaL_reg window_methods[] =
    {
        LUA_CLASS_METHODS(window)
        { "__call", luaH_window_new },
        { NULL, NULL }
    };

    static const struct luaL_reg window_meta[] =
    {
        LUA_OBJECT_META(window)
        { "set_child", luaH_window_set_child },
        { "__index", luaH_window_index },
        { "__newindex", luaH_window_newindex },
        { "__gc", luaH_window_gc },
        { NULL, NULL }
    };

    luaH_class_setup(L, &window_class, "window", (lua_class_allocator_t) window_new,
            NULL, NULL, window_methods, window_meta);

    luaH_class_add_property(&window_class, L_TK_TITLE,
            NULL,
            (lua_class_propfunc_t) luaH_window_get_title,
            (lua_class_propfunc_t) luaH_window_set_title);

    luaH_class_add_property(&window_class, L_TK_CHILD,
            NULL,
            (lua_class_propfunc_t) luaH_window_get_child,
            NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
