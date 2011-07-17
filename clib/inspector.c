/*
 * inspector.c - WebKitWebInspector wrapper
 *
 * Copyright (C) 2010 Fabian Streitel <karottenreibe@gmail.com>
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

#include "globalconf.h"
#include "clib/inspector.h"
#include "clib/widget.h"
#include "widgets/webview.h"

static lua_class_t inspector_class;
LUA_OBJECT_FUNCS(inspector_class, inspector_t, inspector)

/* creates the inspector's webview widget */
static webview_data_t *
inspector_create_widget(inspector_t *i)
{
    lua_State *L = globalconf.L;
    /* create new webview widget */
    lua_newtable(L);
    lua_pushstring(L, "type");
    lua_pushstring(L, "webview");
    lua_rawset(L, -3);
    /* move to absolute index 2 -- needed for luaH_class_new */
    lua_insert(L, 1);
    lua_pushnil(L);
    lua_insert(L, 1);
    /* call widget constructor */
    luaH_widget_new(L);
    widget_t *new = luaH_checkwidget(L, -1);
    i->widget = new;
    /* clean up the stack again */
    lua_remove(L, 1);
    lua_remove(L, 1);
    lua_pop(L, 1);
    /* fix attached size */
    gtk_widget_set_size_request(i->widget->widget, -1, 300);
    return new->data;
}

/* emits the signal of the given name on the inspector, passing the inspected
 * webview and the inspector's webview as arguments */
static void
inspector_emit_signal(inspector_t *i, const char *signal_name)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, i->webview->ref);
    if (!i->widget)
        inspector_create_widget(i);
    luaH_object_push(L, i->widget->ref);
    luaH_object_emit_signal(L, -2, signal_name, 1, 0);
    lua_pop(L, 1);
}

/* callback when an inspector was requested */
static WebKitWebView*
inspect_webview_cb(WebKitWebInspector *inspector, WebKitWebView *v, inspector_t *i)
{
    (void) inspector;
    (void) v;

    webview_data_t *d = inspector_create_widget(i);
    return d->view;
}

/* callback when the inspector is to be shown */
static gboolean
show_window_cb(WebKitWebInspector *inspector, inspector_t *i)
{
    (void) inspector;

    inspector_emit_signal(i, "show-inspector");
    i->visible = TRUE;
    return TRUE;
}

/* closes the inspector window by emitting the \c close-inspector signal.
 * Destroys the inspector's webview afterwards */
static void
inspector_close_window(inspector_t *i)
{
    if (i->visible)
        inspector_emit_signal(i, "close-inspector");
    i->visible = FALSE;
    i->attached = FALSE;
    i->widget = NULL;
}

/* callback when the inspector is to be hidden */
static gboolean
close_window_cb(WebKitWebInspector *inspector, inspector_t *i)
{
    (void) inspector;

    inspector_close_window(i);
    return TRUE;
}

/* callback when the inspector is to be attached */
static gboolean
attach_window_cb(WebKitWebInspector *inspector, inspector_t *i)
{
    (void) inspector;

    inspector_emit_signal(i, "attach-inspector");
    i->attached = TRUE;
    return TRUE;
}

/* callback when the inspector is to be detached */
static gboolean
detach_window_cb(WebKitWebInspector *inspector, inspector_t *i)
{
    (void) inspector;

    inspector_emit_signal(i, "detach-inspector");
    i->attached = FALSE;
    return TRUE;
}

/* shows the inspector */
static gint
luaH_inspector_show(lua_State *L)
{
    inspector_t *i = luaH_checkudata(L, 1, &inspector_class);
    webkit_web_inspector_show(i->inspector);
    return 0;
}

/* hides the inspector */
static gint
luaH_inspector_close(lua_State *L)
{
    inspector_t *i = luaH_checkudata(L, 1, &inspector_class);
    webkit_web_inspector_close(i->inspector);
    return 0;
}

/* pushes a boolean onto the stack that indicates whether the inspector is
 * currently visible */
static gint
luaH_inspector_is_visible(lua_State *L, inspector_t *i)
{
    lua_pushboolean(L, i->visible);
    return 1;
}

/* pushes a boolean onto the stack that indicates whether the inspector is
 * in attached state */
static gint
luaH_inspector_is_attached(lua_State *L, inspector_t *i)
{
    lua_pushboolean(L, i->attached);
    return 1;
}

/* pushes the inspector's widget onto the stack */
static gint
luaH_inspector_get_widget(lua_State *L, inspector_t *i)
{
    if (!i->widget)
        inspector_create_widget(i);
    luaH_object_push(L, i->widget->ref);
    return 1;
}

/** Creates a new inspector.
 *
 * \param L The Lua VM state.
 * \param w A webview widget.
 *
 * \luastack
 * \lreturn An inspector object.
 */
inspector_t *
luaH_inspector_new(lua_State *L, widget_t *w)
{
    inspector_class.allocator(L);
    inspector_t *i = luaH_checkudata(L, -1, &inspector_class);

    i->ref = luaH_object_ref(L, -1);
    i->webview = w;
    i->widget = NULL;
    i->visible = FALSE;
    i->attached = FALSE;
    webview_data_t *d = w->data;
    i->inspector = webkit_web_view_get_inspector(d->view);

    /* connect inspector signals */
    g_object_connect(G_OBJECT(i->inspector),
      "signal::inspect-web-view",            G_CALLBACK(inspect_webview_cb),   i,
      "signal::show-window",                 G_CALLBACK(show_window_cb),       i,
      "signal::close-window",                G_CALLBACK(close_window_cb),      i,
      "signal::attach-window",               G_CALLBACK(attach_window_cb),     i,
      "signal::detach-window",               G_CALLBACK(detach_window_cb),     i,
      NULL);

    return i;
}

/** Destroys the given inspector. */
void
inspector_destroy(lua_State *L, inspector_t *i)
{
    /* manually close the window to prevent segfaults */
    if (i->visible)
        inspector_close_window(i);
    /* unref the inspector so it can be collected by Lua */
    luaH_object_unref(L, i->ref);
}

/** Frees the given inspector's resources. */
static gint
luaH_inspector_gc(lua_State *L)
{
    return luaH_object_gc(L);
}

/** Creates the Lua inspector class. */
void
inspector_class_setup(lua_State *L)
{
    static const struct luaL_reg inspector_methods[] =
    {
        LUA_CLASS_METHODS(inspector)
        { NULL, NULL }
    };

    static const struct luaL_reg inspector_meta[] =
    {
        LUA_OBJECT_META(inspector)
        LUA_CLASS_META
        { "show", luaH_inspector_show },
        { "close", luaH_inspector_close },
        { "__gc", luaH_inspector_gc },
        { NULL, NULL },
    };

    luaH_class_setup(L, &inspector_class, "inspector",
                     (lua_class_allocator_t) inspector_new,
                     luaH_class_index_miss_property, luaH_class_newindex_miss_property,
                     inspector_methods, inspector_meta);
    luaH_class_add_property(&inspector_class, L_TK_WIDGET,
                            (lua_class_propfunc_t) NULL,
                            (lua_class_propfunc_t) luaH_inspector_get_widget,
                            (lua_class_propfunc_t) NULL);
    luaH_class_add_property(&inspector_class, L_TK_ATTACHED,
                            (lua_class_propfunc_t) NULL,
                            (lua_class_propfunc_t) luaH_inspector_is_attached,
                            (lua_class_propfunc_t) NULL);
    luaH_class_add_property(&inspector_class, L_TK_VISIBLE,
                            (lua_class_propfunc_t) NULL,
                            (lua_class_propfunc_t) luaH_inspector_is_visible,
                            (lua_class_propfunc_t) NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
