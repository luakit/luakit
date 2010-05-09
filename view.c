/*
 * view.c - webkit webview widget
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
#include "util.h"
#include "lualib.h"
#include "luaclass.h"
#include "luaobject.h"
#include "luafuncs.h"

#include "view.h"

LUA_CLASS_FUNCS(view, view_class)

view_t *
view_new(lua_State *L) {
    debug("view new");
    view_t *v = lua_newuserdata(L, sizeof(view_t));
    p_clear(v, 1);

    v->signals = signal_tree_new();

    /* create webkit webview widget */
    v->view = WEBKIT_WEB_VIEW(webkit_web_view_new());

    /* create scrolled window for webview */
    v->scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(v->scroll),
        GTK_POLICY_NEVER, GTK_POLICY_NEVER);
    gtk_container_add(GTK_CONTAINER(v->scroll), GTK_WIDGET(v->view));

    /* setup */
    gtk_widget_show(GTK_WIDGET(v->view));
    gtk_widget_show(v->scroll);
    webkit_web_view_set_full_content_zoom(v->view, TRUE);
    // TODO this is here just so that I know it works
    gtk_notebook_append_page(GTK_NOTEBOOK(luakit.nbook), v->scroll, NULL);

    /* make the view instance indexable by the scroll widget */
    g_hash_table_insert(luakit.tabs, (gpointer) v->scroll, (gpointer) v);

    luaH_settype(L, &(view_class));
    lua_newtable(L);
    lua_newtable(L);
    lua_setmetatable(L, -2);
    lua_setfenv(L, -2);
    lua_pushvalue(L, -1);
    luaH_class_emit_signal(L, &(view_class), "new", 1);
    return v;
}

static gint
luaH_view_gc(lua_State *L) {
    view_t *v = luaH_checkudata(L, 1, &view_class);
    debug("gc view at %p", v);

    /* remove from tabs list */
    g_hash_table_remove(luakit.tabs, (gpointer) v->scroll);

    /* destroy gtk widgets */
    gtk_widget_destroy(GTK_WIDGET(v->scroll));
    gtk_widget_destroy(GTK_WIDGET(v->view));


    free(v);
    v = NULL;
    return luaH_object_gc(L);
}

/* Create a new view */
static gint
luaH_view_new(lua_State *L) {
    luaH_class_new(L, &view_class);
    luaH_checkudata(L, -1, &view_class);
    return 1;
}

/** Generic widget.
 * \param L The Lua VM state.
 * \return The number of elements pushed on stack.
 * \luastack
 * \lfield visible The widget visibility.
 * \lfield mouse_enter A function to execute when the mouse enter the widget.
 * \lfield mouse_leave A function to execute when the mouse leave the widget.
 */
static gint
luaH_view_index(lua_State *L) {
    luaH_dumpstack(L);
    size_t len;
    // TODO is 2 correct?
    const char *prop = luaL_checklstring(L, 2, &len);

    /* Try standard method */
    if(luaH_class_index(L))
        return 1;

    /* Then call special view index */
    view_t *view = luaH_checkudata(L, 1, &view_class);
    return view->index ? view->index(L, prop) : 0;
}

/** Generic widget newindex.
 * \param L The Lua VM state.
 * \return The number of elements pushed on stack.
 */
static gint
luaH_view_newindex(lua_State *L) {
    size_t len;
    // TODO is 2 correct?
    const char *prop = luaL_checklstring(L, 2, &len);

    /* Try standard method */
    luaH_class_newindex(L);

    /* Then call special widget newindex */
    view_t *view = luaH_checkudata(L, 1, &view_class);
    return view->newindex ? view->newindex(L, prop) : 0;
}

static gint
luaH_view_get_uri(lua_State *L, view_t *v) {
    lua_pushstring(L, v->uri);
    return 1;
}

static gint
luaH_view_set_uri(lua_State *L, view_t *v) {
    const gchar *uri = luaL_checkstring(L, -1);
    /* Make sure url starts with scheme */
    uri = g_strrstr(uri, "://") ? g_strdup(uri) :
        g_strdup_printf("http://%s", uri);

    webkit_web_view_load_uri(v->view, uri);
    debug("navigating view at %p to %s", v, uri);

    luaH_object_emit_signal(L, -3, "webview::uri", 0);
    return 0;
}

void
view_class_setup(lua_State *L) {

    view_class.properties = (lua_class_property_array_t*) g_tree_new((GCompareFunc) strcmp);
    view_class.signals = signal_tree_new();

    static const struct luaL_reg view_methods[] = {
        LUA_CLASS_METHODS(view)
        { "__call", luaH_view_new },
        { NULL, NULL }
    };

    static const struct luaL_reg view_meta[] = {
        LUA_OBJECT_META(view)
        { "__index", luaH_view_index },
        { "__newindex", luaH_view_newindex },
        { "__gc", luaH_view_gc },
        { NULL, NULL }
    };

    luaH_class_setup(L, &view_class, "view", (lua_class_allocator_t) view_new,
         NULL, NULL, view_methods, view_meta);

    luaH_class_add_property(&view_class, "uri",
        (lua_class_propfunc_t) luaH_view_set_uri,
        (lua_class_propfunc_t) luaH_view_get_uri,
        (lua_class_propfunc_t) luaH_view_set_uri);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
