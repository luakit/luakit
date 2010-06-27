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

/* TODO
 *  - On window destroy detach the child widget
 *  - Add some way of getting a list or count of the number of windows active
 *  - Add ability to remove and change child widget on the fly
 */

#include "globalconf.h"
#include "luah.h"
#include "window.h"

LUA_OBJECT_FUNCS(window_class, window_t, window);

void
destroy_win_cb(GtkObject *win, window_t *w)
{
    (void) win;

    if (!w->win)
        return;

    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "destroy", 0, 0);
    lua_pop(L, 1);

    gtk_widget_destroy(w->win);
    w->win = NULL;

    if (w->icon) {
        g_free(w->icon);
        w->icon = NULL;
    }
}

static gint
luaH_window_gc(lua_State *L)
{
    window_t *w = luaH_checkudata(L, 1, &window_class);
    if (w->win)
        destroy_win_cb(NULL, w);

    return luaH_object_gc(L);
}

static void
child_add_cb(GtkContainer *win, GtkWidget *widget, window_t *w)
{
    (void) win;
    (void) widget;
    debug("child add cb");

    widget_t *child = w->child;

    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    luaH_object_emit_signal(L, -1, "attached", 0, 0);
    luaH_object_emit_signal(L, -2, "add", 1, 0);
    lua_pop(L, 1);
}

static void
child_remove_cb(GtkContainer *win, GtkWidget *widget, window_t *w)
{
    (void) win;
    (void) widget;

    widget_t *child = w->child;
    w->child = NULL;
    child->parent = NULL;

    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_push(L, child->ref);
    luaH_object_emit_signal(L, -1, "detached", 0, 0);
    luaH_object_emit_signal(L, -2, "remove", 1, 0);
    lua_pop(L, 1);
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

    /* Attach callbacks to window signals */
    g_signal_connect(G_OBJECT(w->win), "destroy", G_CALLBACK(destroy_win_cb),  w);
    g_signal_connect(G_OBJECT(w->win), "add",     G_CALLBACK(child_add_cb),    w);
    g_signal_connect(G_OBJECT(w->win), "remove",  G_CALLBACK(child_remove_cb), w);

    /* Catch all events */
    gdk_window_set_events(GTK_WIDGET(w->win)->window, GDK_ALL_EVENTS_MASK);

    w->icon = NULL;

    /* show new window */
    gtk_widget_show(w->win);

    gtk_window_set_title(GTK_WINDOW(w->win), "luakit");

    luaH_object_emit_signal(L, -1, "init", 0, 0);

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
    if (w->title)
        g_free(w->title);
    w->title = g_strdup(luaL_checklstring(L, 3, &len));
    gtk_window_set_title(GTK_WINDOW(w->win), w->title);
    luaH_object_emit_signal(L, 1, "property::title", 0, 0);
    return 0;
}

static gint
luaH_window_get_title(lua_State *L, window_t *w)
{
    lua_pushstring(L, NONULL(w->title));
    return 1;
}

static gint
luaH_window_set_icon(lua_State *L, window_t *w)
{
    size_t len;
    if (w->icon)
        g_free(w->icon);
    w->icon = g_strdup(luaL_checklstring(L, 3, &len));
    if (file_exists(w->icon))
        gtk_window_set_icon_from_file(GTK_WINDOW(w->win), w->icon, NULL);
    else
        warn("Unable to open icon at \"%s\"", w->icon);
    luaH_object_emit_signal(L, 1, "property::icon", 0, 0);
    return 0;
}

static gint
luaH_window_get_icon(lua_State *L, window_t *w)
{
    lua_pushstring(L, NONULL(w->icon));
    return 1;
}

static gint
luaH_window_set_child(lua_State *L)
{
    window_t *w = luaH_checkudata(L, 1, &window_class);
    widget_t *child = luaH_widget_checkgtk(L,
            luaH_checkudata(L, 2, &widget_class));

    if (w->child)
        luaL_error(L, "window already has child widget");

    if (child->parent || child->window)
        luaL_error(L, "widget already has parent window");

    child->window = w;
    w->child = child;

    gtk_container_add(GTK_CONTAINER(w->win), GTK_WIDGET(child->widget));
    return 0;
}

static gint
luaH_window_get_child(lua_State *L, window_t *w)
{
    if (w->child)
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

    luaH_class_add_property(&window_class, L_TK_ICON,
            (lua_class_propfunc_t) luaH_window_set_icon,
            (lua_class_propfunc_t) luaH_window_get_icon,
            (lua_class_propfunc_t) luaH_window_set_icon);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
