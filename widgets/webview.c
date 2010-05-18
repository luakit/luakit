/*
 * webview.c - webkit webview widget
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

#include <JavaScriptCore/JavaScript.h>
#include <webkit/webkit.h>

#include "luakit.h"
#include "luah.h"
#include "widget.h"

typedef struct
{
    /* webkit webview */
    WebKitWebView *view;
    /* scrollable area which holds the webview */
    GtkWidget *scroll;

    /* state variables */
    gchar *uri;
    gchar *title;
    gint progress;

} webview_data_t;

void
progress_change_cb(WebKitWebView *v, gint p, widget_t *w) {
    (void) v;

    webview_data_t *d = w->data;
    d->progress = p;

    lua_State *L = luakit.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "property::progress", 0);
    lua_pop(L, 1);
}

void
title_changed_cb(WebKitWebView *v, WebKitWebFrame *f, const gchar *title, widget_t *w) {
    (void) f;
    (void) v;

    /* save title in data struct */
    webview_data_t *d = w->data;
    if (d->title)
        g_free(d->title);
    d->title = g_strdup(title);

    lua_State *L = luakit.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "property::title", 0);
    lua_pop(L, 1);
}

void
load_start_cb(WebKitWebView *v, WebKitWebFrame *f, widget_t *w) {
    (void) v;
    (void) f;

    /* reset progress */
    webview_data_t *d = w->data;
    d->progress = 0;

    lua_State *L = luakit.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "property::progress", 0);
    luaH_object_emit_signal(L, -1, "webview::load-start", 0);
    lua_pop(L, 1);
}

void
load_commit_cb(WebKitWebView *v, WebKitWebFrame *f, widget_t *w) {
    (void) v;

    /* update uri after redirects, etc */
    webview_data_t *d = w->data;
    if (d->uri)
        g_free(d->uri);
    d->uri = g_strdup(webkit_web_frame_get_uri(f));

    lua_State *L = luakit.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "property::uri", 0);
    luaH_object_emit_signal(L, -1, "webview::load-commit", 0);
    lua_pop(L, 1);
}

void
load_finish_cb(WebKitWebView *v, WebKitWebFrame *f, widget_t *w) {
    (void) v;
    (void) f;

    lua_State *L = luakit.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "webview::load-finish", 0);
    lua_pop(L, 1);
}

/* The __index method for the webview object */
static gint
luaH_webview_index(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    webview_data_t *d = w->data;

    switch(token)
    {
      case L_TK_URI:
        lua_pushstring(L, d->uri);
        return 1;

      case L_TK_TITLE:
        lua_pushstring(L, d->title);
        return 1;

      case L_TK_PROGRESS:
        lua_pushnumber(L, d->progress);
        return 1;

      default:
        break;
    }
    return 0;
}

/* The __newindex method for the webview object */
static gint
luaH_webview_newindex(lua_State *L, luakit_token_t token)
{
    size_t len = 0;
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    webview_data_t *d = w->data;
    const gchar *str = NULL;

    switch(token)
    {
      case L_TK_URI:
        str = luaL_checklstring(L, 3, &len);
        if (d->uri)
            g_free(d->uri);
        d->uri = g_strrstr(str, "://") ? g_strdup(str) :
            g_strdup_printf("http://%s", str);
        webkit_web_view_load_uri(d->view, d->uri);
        luaH_object_emit_signal(L, 1, "property::uri", 0);
        break;

      default:
        break;
    }
    return 0;
}

static void
webview_destructor(widget_t *w)
{
    debug("destructing widget");

    webview_data_t *d = w->data;

    /* destory gtk widgets */
    gtk_widget_destroy(GTK_WIDGET(d->scroll));
    gtk_widget_destroy(GTK_WIDGET(d->view));

    g_free(d);
    d = NULL;
    w->widget = NULL;
    w->parent = NULL;
    w->window = NULL;
}

widget_t *
widget_webview(widget_t *w)
{
    w->index = luaH_webview_index;
    w->newindex = luaH_webview_newindex;
    w->destructor = webview_destructor;

    webview_data_t *d = w->data = g_new0(webview_data_t, 1);

    /* set initial values */
    d->progress = 0;

    /* create webkit webview widget */
    d->view = WEBKIT_WEB_VIEW(webkit_web_view_new());

    /* connect webview signals */
    g_signal_connect(G_OBJECT(d->view), "title-changed", G_CALLBACK(title_changed_cb), w);
    g_signal_connect(G_OBJECT(d->view), "load-started", G_CALLBACK(load_start_cb), w);
    g_signal_connect(G_OBJECT(d->view), "load-committed", G_CALLBACK(load_commit_cb), w);
    g_signal_connect(G_OBJECT(d->view), "load-finished", G_CALLBACK(load_finish_cb), w);
    g_signal_connect(G_OBJECT(d->view), "load-progress-changed", G_CALLBACK(progress_change_cb), w);

    /* create scrolled window for webview */
    w->widget = d->scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(d->scroll),
        GTK_POLICY_NEVER, GTK_POLICY_NEVER);
    gtk_container_add(GTK_CONTAINER(d->scroll), GTK_WIDGET(d->view));

    /* setup */
    gtk_widget_show(GTK_WIDGET(d->view));
    gtk_widget_show(d->scroll);
    webkit_web_view_set_full_content_zoom(d->view, TRUE);

    debug("child widget %p", w->widget);

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
