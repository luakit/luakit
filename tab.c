/*
 * tab.c - webkit webview widget wrapper
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

#include "tab.h"

LUA_CLASS_FUNCS(tab, tab_class)

void
title_changed_cb(WebKitWebView *v, WebKitWebFrame *f, const gchar *title, tab_t *t) {
    (void) f;
    (void) v;

    luaH_object_push(luakit.L, t->ref);
    lua_pushstring(luakit.L, g_strdup(title));
    luaH_object_emit_signal(luakit.L, -2, "webview::title_changed", 1);
    debug("hello");
    lua_pop(luakit.L, 1);
}

tab_t *
tab_new(lua_State *L) {
    tab_t *t = lua_newuserdata(L, sizeof(tab_t));
    p_clear(t, 1);

    t->anchored = FALSE;
    t->signals = signal_tree_new();
    /* create webkit webview widget */
    t->view = WEBKIT_WEB_VIEW(webkit_web_view_new());

    /* connect webview signals */
    g_signal_connect(G_OBJECT(t->view), "title-changed", G_CALLBACK(title_changed_cb), t);

    /* create scrolled window for webview */
    t->scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(t->scroll),
        GTK_POLICY_NEVER, GTK_POLICY_NEVER);
    gtk_container_add(GTK_CONTAINER(t->scroll), GTK_WIDGET(t->view));

    /* setup */
    gtk_widget_show(GTK_WIDGET(t->view));
    gtk_widget_show(t->scroll);
    webkit_web_view_set_full_content_zoom(t->view, TRUE);

    luaH_settype(L, &(tab_class));
    lua_newtable(L);
    lua_newtable(L);
    lua_setmetatable(L, -2);
    lua_setfenv(L, -2);
    lua_pushvalue(L, -1);
    luaH_class_emit_signal(L, &(tab_class), "new", 1);

    return t;
}

static gint
luaH_tab_gc(lua_State *L) {
    tab_t *t = luaH_checkudata(L, 1, &tab_class);
    debug("gc tab at %p", t);

    /* remove from tabs list */
    g_hash_table_remove(luakit.tabs, (gpointer) t->scroll);

    /* destroy gtk widgets */
    gtk_widget_destroy(GTK_WIDGET(t->scroll));
    gtk_widget_destroy(GTK_WIDGET(t->view));

    free(t);
    t = NULL;
    return luaH_object_gc(L);
}

/* Create a new tab */
static gint
luaH_tab_new(lua_State *L) {
    luaH_class_new(L, &tab_class);
    luaH_checkudata(L, -1, &tab_class);
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
luaH_tab_index(lua_State *L) {
    size_t len;
    const char *prop = luaL_checklstring(L, 2, &len);

    /* Try standard method */
    if(luaH_class_index(L))
        return 1;

    /* Then call special tab index */
    tab_t *tab = luaH_checkudata(L, 1, &tab_class);
    return tab->index ? tab->index(L, prop) : 0;
}

/** Generic widget newindex.
 * \param L The Lua VM state.
 * \return The number of elements pushed on stack.
 */
static gint
luaH_tab_newindex(lua_State *L) {
    size_t len;
    // TODO is 2 correct?
    const char *prop = luaL_checklstring(L, 2, &len);

    /* Try standard method */
    luaH_class_newindex(L);

    /* Then call special widget newindex */
    tab_t *tab = luaH_checkudata(L, 1, &tab_class);
    return tab->newindex ? tab->newindex(L, prop) : 0;
}

static gint
luaH_tab_get_uri(lua_State *L, tab_t *t) {
    lua_pushstring(L, t->uri);
    return 1;
}

static gint
luaH_tab_set_uri(lua_State *L, tab_t *t) {
    /* get new uri from stack */
    const gchar *uri = luaL_checkstring(L, -1);

    if (t->uri)
        g_free(t->uri);

    /* Make sure url starts with scheme */
    t->uri = g_strrstr(uri, "://") ? g_strdup(uri) :
        g_strdup_printf("http://%s", uri);

    webkit_web_view_load_uri(t->view, t->uri);

    /* place new uri in stack and raise property signal */
    lua_pushstring(L, NONULL(t->uri));
    luaH_object_emit_signal(L, -4, "webview::uri", 1);
    return 0;
}

static gint
luaH_tab_get_title(lua_State *L, tab_t *t) {
    lua_pushstring(L, NONULL(t->title));
    luaH_dumpstack(L);
    return 1;
}

static gint
luaH_tab_set_title(lua_State *L, tab_t *t) {
    /* get new title from stack */
    const gchar *title = luaL_checkstring(L, -1);

    if (t->uri)
        g_free(t->uri);

    t->title = g_strdup(title);

    if (t->anchored)
        gtk_notebook_set_tab_label_text(GTK_NOTEBOOK(luakit.nbook),
            t->scroll, t->title);

    lua_pushvalue(L, -1);
    luaH_object_emit_signal(luakit.L, -4, "property::title", 1);
    return 0;
}

void
tab_class_setup(lua_State *L) {

    tab_class.properties = (lua_class_property_array_t*) g_tree_new((GCompareFunc) strcmp);
    tab_class.signals = signal_tree_new();

    static const struct luaL_reg tab_methods[] = {
        LUA_CLASS_METHODS(tab)
        { "__call", luaH_tab_new },
        { NULL, NULL }
    };

    static const struct luaL_reg tab_meta[] = {
        LUA_OBJECT_META(tab)
        { "__index", luaH_tab_index },
        { "__newindex", luaH_tab_newindex },
        { "__gc", luaH_tab_gc },
        { NULL, NULL }
    };

    luaH_class_setup(L, &tab_class, "tab", (lua_class_allocator_t) tab_new,
         luaH_class_index_miss_property, luaH_class_newindex_miss_property,
         tab_methods, tab_meta);

    luaH_class_add_property(&tab_class, "uri",
        (lua_class_propfunc_t) luaH_tab_set_uri,
        (lua_class_propfunc_t) luaH_tab_get_uri,
        (lua_class_propfunc_t) luaH_tab_set_uri);

    luaH_class_add_property(&tab_class, "title",
        (lua_class_propfunc_t) luaH_tab_set_title,
        (lua_class_propfunc_t) luaH_tab_get_title,
        (lua_class_propfunc_t) luaH_tab_set_title);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
