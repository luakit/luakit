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
#include "globalconf.h"
#include "widgets/common.h"
#include "luah.h"
#include "widget.h"

typedef struct
{
    /* webkit webview */
    WebKitWebView *view;
    /* scrollable area which holds the webview */
    GtkWidget *scroll;

    /* state variables */
    gchar     *uri;
    gchar     *title;
    gchar     *hovered_uri;
    gint      progress;

    /* appearance */
    gdouble   zoom;
    gboolean  full_zoom;
    gboolean  autoload_images;
    gboolean  autoshrink_images;
    gboolean  print_backgrounds;
    gchar     *stylesheet_uri;

    /* font settings */
    gint      default_font_size;
    gint      monospace_font_size;
    gint      minimum_font_size;
    gchar     *default_font_family;
    gchar     *monospace_font_family;
    gchar     *sans_serif_font_family;
    gchar     *serif_font_family;
    gchar     *fantasy_font_family;
    gchar     *cursive_font_family;

    /* browsing options */
    gboolean  disable_plugins;
    gboolean  disable_scripts;
    gboolean  enable_spellcheck;
    gboolean  enable_private;

    /* request related options */
    gchar     *useragent;

} webview_data_t;

void
update_uri(widget_t *w, const gchar *uri)
{
    lua_State *L = globalconf.L;
    webview_data_t *d = w->data;

    if (!g_strcmp0(d->uri, uri))
        return;
    if (d->uri)
        g_free(d->uri);
    d->uri = g_strdup(uri);
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "property::uri", 0, 0);
    lua_pop(L, 1);
}

void
progress_cb(WebKitWebView *v, gint p, widget_t *w)
{
    (void) v;
    lua_State *L = globalconf.L;
    webview_data_t *d = w->data;

    d->progress = p;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "property::progress", 0, 0);
    lua_pop(L, 1);
}

void
title_changed_cb(WebKitWebView *v, WebKitWebFrame *f, const gchar *title, widget_t *w)
{
    (void) f;
    (void) v;
    lua_State *L = globalconf.L;
    webview_data_t *d = w->data;

    if (d->title)
        g_free(d->title);
    d->title = g_strdup(title);
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "property::title", 0, 0);
    lua_pop(L, 1);
}

void
load_start_cb(WebKitWebView *v, WebKitWebFrame *f, widget_t *w)
{
    (void) v;
    (void) f;
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "load-start", 0, 0);
    lua_pop(L, 1);
}

void
load_commit_cb(WebKitWebView *v, WebKitWebFrame *f, widget_t *w)
{
    (void) v;
    lua_State *L = globalconf.L;

    update_uri(w, webkit_web_frame_get_uri(f));
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "load-commit", 0, 0);
    lua_pop(L, 1);
}

void
load_finish_cb(WebKitWebView *v, WebKitWebFrame *f, widget_t *w)
{
    (void) v;
    lua_State *L = globalconf.L;

    update_uri(w, webkit_web_frame_get_uri(f));
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "load-finish", 0, 0);
    lua_pop(L, 1);
}

void
link_hover_cb(WebKitWebView *v, const char *t, const gchar *link, widget_t *w)
{
    (void) v;
    (void) t;
    lua_State *L = globalconf.L;
    webview_data_t *d = w->data;

    /* links are identical, do nothing */
    if (d->hovered_uri && !g_strcmp0(d->hovered_uri, link))
        return;

    luaH_object_push(L, w->ref);

    if (d->hovered_uri) {
        lua_pushstring(L, d->hovered_uri);
        luaH_object_emit_signal(L, -2, "link-unhover", 1, 0);
        g_free(d->hovered_uri);
        d->hovered_uri = NULL;
    }

    if (link) {
        d->hovered_uri = g_strdup(link);
        lua_pushstring(L, d->hovered_uri);
        luaH_object_emit_signal(L, -2, "link-hover", 1, 0);
    }

    luaH_object_emit_signal(L, -1, "property::hovered_uri", 0, 0);
    lua_pop(L, 1);
}

/* Raises the "navigation-request" signal on a webkit navigation policy
 * decision request. The default action is to load the requested uri.
 *
 * The signal handler is able to:
 *  - return true for the handler execution to stop and the request to continue
 *  - return false for the handler execution to stop and the request to hault
 *  - do nothing and give the navigation decision to the next signal handler
 *
 * This signal is also where you would attach custom scheme handlers to take
 * over the navigation request by launching an external application.
 */
gboolean
navigation_decision_cb(WebKitWebView *v, WebKitWebFrame *f,
        WebKitNetworkRequest *r, WebKitWebNavigationAction *a,
        WebKitWebPolicyDecision *p, widget_t *w)
{
    (void) v;
    (void) f;
    (void) a;

    lua_State *L = globalconf.L;
    const gchar *uri = webkit_network_request_get_uri(r);
    gint ret;

    debug("Navigation requested: %s", uri);

    luaH_object_push(L, w->ref);
    lua_pushstring(L, uri);
    ret = luaH_object_emit_signal(L, -2, "navigation-request", 1, 1);

    if (ret && !luaH_checkboolean(L, -1))
        /* User responded with false, do not continue navigation request */
        webkit_web_policy_decision_ignore(p);
    else
        webkit_web_policy_decision_use(p);

    lua_pop(L, ret);
    return TRUE;
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

      case L_TK_DISABLE_SCRIPTS:
        lua_pushboolean(L, d->disable_scripts);
        return 1;

      case L_TK_DISABLE_PLUGINS:
        lua_pushboolean(L, d->disable_plugins);
        return 1;

      case L_TK_DEFAULT_FONT_FAMILY:
        lua_pushstring(L, d->default_font_family);
        return 1;

      case L_TK_MONOSPACE_FONT_FAMILY:
        lua_pushstring(L, d->monospace_font_family);
        return 1;

      case L_TK_SANS_SERIF_FONT_FAMILY:
        lua_pushstring(L, d->sans_serif_font_family);
        return 1;

      case L_TK_SERIF_FONT_FAMILY:
        lua_pushstring(L, d->serif_font_family);
        return 1;

      case L_TK_CURSIVE_FONT_FAMILY:
        lua_pushstring(L, d->cursive_font_family);
        return 1;

      case L_TK_FANTASY_FONT_FAMILY:
        lua_pushstring(L, d->fantasy_font_family);
        return 1;

      case L_TK_ZOOM:
        lua_pushnumber(L, d->zoom);
        return 1;

      case L_TK_FULL_ZOOM:
        lua_pushboolean(L, d->full_zoom);
        return 1;

      case L_TK_HOVERED_URI:
        lua_pushstring(L, d->hovered_uri);
        return 1;

      case L_TK_DEFAULT_FONT_SIZE:
        lua_pushnumber(L, d->minimum_font_size);
        return 1;

      case L_TK_MONOSPACE_FONT_SIZE:
        lua_pushnumber(L, d->monospace_font_size);
        return 1;

      case L_TK_MINIMUM_FONT_SIZE:
        lua_pushnumber(L, d->minimum_font_size);
        return 1;

      case L_TK_ENABLE_SPELLCHECK:
        lua_pushboolean(L, d->enable_spellcheck);
        return 1;

      case L_TK_ENABLE_PRIVATE:
        lua_pushboolean(L, d->enable_private);
        return 1;

      case L_TK_AUTOLOAD_IMAGES:
        lua_pushboolean(L, d->autoload_images);
        return 1;

      case L_TK_AUTOSHRINK_IMAGES:
        lua_pushboolean(L, d->autoshrink_images);
        return 1;

      case L_TK_PRINT_BACKGROUNDS:
        lua_pushboolean(L, d->print_backgrounds);
        return 1;

      case L_TK_STYLESHEET_URI:
        lua_pushstring(L, d->stylesheet_uri);
        return 1;

      case L_TK_USERAGENT:
        lua_pushstring(L, d->useragent);
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
    size_t len;
    gchar *tmp;
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    webview_data_t *d = w->data;
    GObject *ws = G_OBJECT(webkit_web_view_get_settings(d->view));

#define SET_PROP(prop)                             \
    tmp = (gchar*) luaL_checklstring(L, 3, &len);  \
    if (prop) g_free(prop);                        \
    prop = g_strdup(tmp);

    switch(token)
    {
      case L_TK_URI:
        tmp = (gchar*) luaL_checklstring(L, 3, &len);
        if (d->uri)
            g_free(d->uri);
        d->uri = g_strrstr(tmp, "://") ? g_strdup(tmp) :
            g_strdup_printf("http://%s", tmp);
        webkit_web_view_load_uri(d->view, d->uri);
        break;

      case L_TK_DISABLE_SCRIPTS:
        d->disable_scripts = luaH_checkboolean(L, 3);
        g_object_set(ws, "enable-scripts", !d->disable_scripts, NULL);
        break;

      case L_TK_DISABLE_PLUGINS:
        d->disable_plugins = luaH_checkboolean(L, 3);
        g_object_set(ws, "enable-plugins", !d->disable_plugins, NULL);
        break;

    /* TODO: It would be nice to have these changed changed via a font table
             like view.font.monospace, view.font.default, ... */

      case L_TK_DEFAULT_FONT_FAMILY:
        SET_PROP(d->default_font_family);
        g_object_set(ws, "default-font-family", d->default_font_family, NULL);
        break;

      case L_TK_MONOSPACE_FONT_FAMILY:
        SET_PROP(d->monospace_font_family);
        g_object_set(ws, "monospace-font-family",
            d->monospace_font_family, NULL);
        break;

      case L_TK_SANS_SERIF_FONT_FAMILY:
        SET_PROP(d->sans_serif_font_family);
        g_object_set(ws, "sans_serif-font-family",
            d->sans_serif_font_family, NULL);
        break;

      case L_TK_SERIF_FONT_FAMILY:
        SET_PROP(d->serif_font_family);
        g_object_set(ws, "serif-font-family", d->serif_font_family, NULL);
        break;

      case L_TK_CURSIVE_FONT_FAMILY:
        SET_PROP(d->cursive_font_family);
        g_object_set(ws, "cursive-font-family", d->cursive_font_family, NULL);
        break;

      case L_TK_FANTASY_FONT_FAMILY:
        SET_PROP(d->fantasy_font_family);
        g_object_set(ws, "fantasy-font-family", d->fantasy_font_family, NULL);
        break;

      case L_TK_DEFAULT_FONT_SIZE:
        d->default_font_size = luaL_checknumber(L, 3);
        if (d->default_font_size > 0)
            g_object_set(ws, "default-font-size", d->default_font_size, NULL);
        break;

      case L_TK_MONOSPACE_FONT_SIZE:
        d->monospace_font_size = luaL_checknumber(L, 3);
        if (d->monospace_font_size > 0)
            g_object_set(ws, "default-monospace-font-size",
                d->monospace_font_size, NULL);
        break;

      case L_TK_MINIMUM_FONT_SIZE:
        d->minimum_font_size = luaL_checknumber(L, 3);
        if (d->minimum_font_size > 0)
            g_object_set(ws, "minimum-font-size", d->minimum_font_size, NULL);
        break;

      case L_TK_ZOOM:
        d->zoom = (gdouble) luaL_checknumber(L, 3);
        webkit_web_view_set_zoom_level(d->view, d->zoom);
        break;

      case L_TK_FULL_ZOOM:
        d->full_zoom = luaH_checkboolean(L, 3);
        webkit_web_view_set_full_content_zoom(d->view, d->full_zoom);
        break;

      case L_TK_ENABLE_SPELLCHECK:
        d->enable_spellcheck = luaH_checkboolean(L, 3);
        g_object_set(ws, "enable-spell-checking", d->enable_spellcheck, NULL);
        break;

      case L_TK_ENABLE_PRIVATE:
        d->enable_private = luaH_checkboolean(L, 3);
        g_object_set(ws, "enable-private-browsing", d->enable_private, NULL);
        break;

      case L_TK_AUTOLOAD_IMAGES:
        d->autoload_images = luaH_checkboolean(L, 3);
        g_object_set(ws, "auto-load-images", d->autoload_images, NULL);
        break;

      case L_TK_AUTOSHRINK_IMAGES:
        d->autoshrink_images = luaH_checkboolean(L, 3);
        g_object_set(ws, "auto-shrink-images", d->autoshrink_images, NULL);
        break;

      case L_TK_PRINT_BACKGROUNDS:
        d->print_backgrounds = luaH_checkboolean(L, 3);
        g_object_set(ws, "print-backgrounds", d->print_backgrounds, NULL);
        break;

      case L_TK_STYLESHEET_URI:
        SET_PROP(d->stylesheet_uri);
        g_object_set(ws, "user-stylesheet-uri", d->stylesheet_uri, NULL);
        break;

      case L_TK_USERAGENT:
        SET_PROP(d->useragent);
        g_object_set(ws, "user-agent", d->useragent, NULL);
        break;

      default:
        return 0;
    }

#undef SET_PROP

    tmp = g_strdup_printf("property::%s", luaL_checklstring(L, 2, &len));
    luaH_object_emit_signal(L, 1, tmp, 0, 0);
    g_free(tmp);
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

    /* create webkit webview widget */
    d->view = WEBKIT_WEB_VIEW(webkit_web_view_new());

    /* connect webview signals */
    g_object_connect((GObject*)d->view,
      "signal::focus-in-event",                       (GCallback)focus_cb,               w,
      "signal::focus-out-event",                      (GCallback)focus_cb,               w,
      "signal::hovering-over-link",                   (GCallback)link_hover_cb,          w,
      "signal::key-press-event",                      (GCallback)key_press_cb,           w,
      "signal::key-release-event",                    (GCallback)key_release_cb,         w,
      "signal::load-committed",                       (GCallback)load_commit_cb,         w,
      "signal::load-finished",                        (GCallback)load_finish_cb,         w,
      "signal::load-progress-changed",                (GCallback)progress_cb,            w,
      "signal::load-started",                         (GCallback)load_start_cb,          w,
      "signal::navigation-policy-decision-requested", (GCallback)navigation_decision_cb, w,
      "signal::title-changed",                        (GCallback)title_changed_cb,       w,
      NULL);

    /* create scrolled window for webview */
    w->widget = d->scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(d->scroll),
        GTK_POLICY_NEVER, GTK_POLICY_NEVER);
    gtk_container_add(GTK_CONTAINER(d->scroll), GTK_WIDGET(d->view));

    /* default zoom settings */
    d->zoom = 1;
    d->full_zoom = TRUE;
    webkit_web_view_set_zoom_level(d->view, d->zoom);
    webkit_web_view_set_full_content_zoom(d->view, d->full_zoom);

    /* setup */
    gtk_widget_show(GTK_WIDGET(d->view));
    gtk_widget_show(d->scroll);
    webkit_web_view_set_full_content_zoom(d->view, TRUE);

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
