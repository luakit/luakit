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

#include "luah.h"
#include "widgets/common.h"
#include <JavaScriptCore/JavaScript.h>
#include <webkit/webkit.h>
#include <libsoup/soup.h>
#include "math.h"

static struct {
    SoupSession   *session;
    SoupCookieJar *cookiejar;
} Soup = { NULL, NULL };

typedef enum { BOOL, CHAR, INT, FLOAT, DOUBLE, URI } property_value_type;
typedef enum { SETTINGS, WEBKITVIEW, SOUPSESSION }   property_value_scope;

typedef union {
    gchar    *c;
    gboolean  b;
    gdouble   d;
    gfloat    f;
    gint      i;
} property_tmp_values;

const struct property_t {
    const gchar *name;
    property_value_type type;
    property_value_scope scope;
    gboolean writable;
} properties[] = {
  { "accept-language",                              CHAR,   SOUPSESSION, TRUE  },
  { "accept-language-auto",                         BOOL,   SOUPSESSION, TRUE  },
  { "auto-load-images",                             BOOL,   SETTINGS,    TRUE  },
  { "auto-resize-window",                           BOOL,   SETTINGS,    TRUE  },
  { "auto-shrink-images",                           BOOL,   SETTINGS,    TRUE  },
  { "cursive-font-family",                          CHAR,   SETTINGS,    TRUE  },
  { "custom-encoding",                              CHAR,   WEBKITVIEW,  TRUE  },
  { "default-encoding",                             CHAR,   SETTINGS,    TRUE  },
  { "default-font-family",                          CHAR,   SETTINGS,    TRUE  },
  { "default-font-size",                            INT,    SETTINGS,    TRUE  },
  { "default-monospace-font-size",                  INT,    SETTINGS,    TRUE  },
  { "editable",                                     BOOL,   WEBKITVIEW,  TRUE  },
  { "enable-caret-browsing",                        BOOL,   SETTINGS,    TRUE  },
  { "enable-default-context-menu",                  BOOL,   SETTINGS,    TRUE  },
  { "enable-developer-extras",                      BOOL,   SETTINGS,    TRUE  },
  { "enable-dom-paste",                             BOOL,   SETTINGS,    TRUE  },
  { "enable-file-access-from-file-uris",            BOOL,   SETTINGS,    TRUE  },
  { "enable-html5-database",                        BOOL,   SETTINGS,    TRUE  },
  { "enable-html5-local-storage",                   BOOL,   SETTINGS,    TRUE  },
  { "enable-java-applet",                           BOOL,   SETTINGS,    TRUE  },
  { "enable-offline-web-application-cache",         BOOL,   SETTINGS,    TRUE  },
  { "enable-page-cache",                            BOOL,   SETTINGS,    TRUE  },
  { "enable-plugins",                               BOOL,   SETTINGS,    TRUE  },
  { "enable-private-browsing",                      BOOL,   SETTINGS,    TRUE  },
  { "enable-scripts",                               BOOL,   SETTINGS,    TRUE  },
  { "enable-site-specific-quirks",                  BOOL,   SETTINGS,    TRUE  },
  { "enable-spatial-navigation",                    BOOL,   SETTINGS,    TRUE  },
  { "enable-spell-checking",                        BOOL,   SETTINGS,    TRUE  },
  { "enable-universal-access-from-file-uris",       BOOL,   SETTINGS,    TRUE  },
  { "enable-xss-auditor",                           BOOL,   SETTINGS,    TRUE  },
  { "encoding",                                     CHAR,   WEBKITVIEW,  FALSE },
  { "enforce-96-dpi",                               BOOL,   SETTINGS,    TRUE  },
  { "fantasy-font-family",                          CHAR,   SETTINGS,    TRUE  },
  { "full-content-zoom",                            BOOL,   WEBKITVIEW,  TRUE  },
  { "idle-timeout",                                 INT,    SOUPSESSION, TRUE  },
  { "icon-uri",                                     CHAR,   WEBKITVIEW,  FALSE },
  { "javascript-can-access-clipboard",              BOOL,   SETTINGS,    TRUE  },
  { "javascript-can-open-windows-automatically",    BOOL,   SETTINGS,    TRUE  },
  { "max-conns",                                    INT,    SOUPSESSION, TRUE  },
  { "max-conns-per-host",                           INT,    SOUPSESSION, TRUE  },
  { "minimum-font-size",                            INT,    SETTINGS,    TRUE  },
  { "minimum-logical-font-size",                    INT,    SETTINGS,    TRUE  },
  { "monospace-font-family",                        CHAR,   SETTINGS,    TRUE  },
  { "print-backgrounds",                            BOOL,   SETTINGS,    TRUE  },
  { "progress",                                     DOUBLE, WEBKITVIEW,  FALSE },
  { "proxy-uri",                                    URI,    SOUPSESSION, TRUE  },
  { "resizable-text-areas",                         BOOL,   SETTINGS,    TRUE  },
  { "sans-serif-font-family",                       CHAR,   SETTINGS,    TRUE  },
  { "serif-font-family",                            CHAR,   SETTINGS,    TRUE  },
  { "spell-checking-languages",                     CHAR,   SETTINGS,    TRUE  },
  { "ssl-ca-file",                                  CHAR,   SOUPSESSION, TRUE  },
  { "ssl-strict",                                   BOOL,   SOUPSESSION, TRUE  },
  { "tab-key-cycles-through-elements",              BOOL,   SETTINGS,    TRUE  },
  { "timeout",                                      INT,    SOUPSESSION, TRUE  },
  { "title",                                        CHAR,   WEBKITVIEW,  FALSE },
  { "transparent",                                  BOOL,   WEBKITVIEW,  TRUE  },
  { "use-ntlm",                                     BOOL,   SOUPSESSION, TRUE  },
  { "user-agent",                                   CHAR,   SETTINGS,    TRUE  },
  { "user-stylesheet-uri",                          CHAR,   SETTINGS,    TRUE  },
  { "zoom-level",                                   FLOAT,  WEBKITVIEW,  TRUE  },
  { "zoom-step",                                    FLOAT,  SETTINGS,    TRUE  },
  { NULL,                                           0,      0,      0     },
};

static const gchar*
webview_eval_js(WebKitWebView *view, const gchar *script, const gchar *file) {
    WebKitWebFrame *frame;
    JSGlobalContextRef context;
    JSObjectRef globalobject;
    JSStringRef js_file;
    JSStringRef js_script;
    JSValueRef js_result;
    JSValueRef js_exc = NULL;
    JSStringRef js_result_string;
    GString *result = g_string_new(NULL);
    size_t js_result_size;

    frame = webkit_web_view_get_main_frame(WEBKIT_WEB_VIEW(view));
    context = webkit_web_frame_get_global_context(frame);
    globalobject = JSContextGetGlobalObject(context);

    /* evaluate the script and get return value*/
    js_script = JSStringCreateWithUTF8CString(script);
    js_file = JSStringCreateWithUTF8CString(file);
    js_result = JSEvaluateScript(context, js_script, globalobject, js_file, 0, &js_exc);
    if (js_result && !JSValueIsUndefined(context, js_result)) {
        js_result_string = JSValueToStringCopy(context, js_result, NULL);
        js_result_size = JSStringGetMaximumUTF8CStringSize(js_result_string);

        if (js_result_size) {
            char js_result_utf8[js_result_size];
            JSStringGetUTF8CString(js_result_string, js_result_utf8, js_result_size);
            g_string_assign(result, js_result_utf8);
        }

        JSStringRelease(js_result_string);
    }
    else if (js_exc) {
        size_t size;
        JSStringRef prop, val;
        JSObjectRef exc = JSValueToObject(context, js_exc, NULL);

        printf("Exception occured while executing script:\n");

        /* Print file */
        prop = JSStringCreateWithUTF8CString("sourceURL");
        val = JSValueToStringCopy(context, JSObjectGetProperty(context, exc, prop, NULL), NULL);
        size = JSStringGetMaximumUTF8CStringSize(val);
        if(size) {
            char cstr[size];
            JSStringGetUTF8CString(val, cstr, size);
            printf("At %s", cstr);
        }
        JSStringRelease(prop);
        JSStringRelease(val);

        /* Print line */
        prop = JSStringCreateWithUTF8CString("line");
        val = JSValueToStringCopy(context, JSObjectGetProperty(context, exc, prop, NULL), NULL);
        size = JSStringGetMaximumUTF8CStringSize(val);
        if(size) {
            char cstr[size];
            JSStringGetUTF8CString(val, cstr, size);
            printf(":%s: ", cstr);
        }
        JSStringRelease(prop);
        JSStringRelease(val);

        /* Print message */
        val = JSValueToStringCopy(context, exc, NULL);
        size = JSStringGetMaximumUTF8CStringSize(val);
        if(size) {
            char cstr[size];
            JSStringGetUTF8CString(val, cstr, size);
            printf("%s\n", cstr);
        }
        JSStringRelease(val);
    }

    /* cleanup */
    JSStringRelease(js_script);
    JSStringRelease(js_file);

    return g_string_free(result, FALSE);
}

static gint
luaH_webview_eval_js(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    WebKitWebView *view = WEBKIT_WEB_VIEW(g_object_get_data(G_OBJECT(w->widget), "webview"));
    const gchar *script = luaL_checkstring(L, 2);
    const gchar *filename = luaL_checkstring(L, 3);

    /* evaluate javascript script and push return result onto lua stack */
    const gchar *result = webview_eval_js(view, script, filename);
    lua_pushstring(L, result);
    return 1;
}

static void
progress_cb(WebKitWebView *v, gint p, widget_t *w)
{
    (void) v;
    (void) p;

    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "progress-update", 0, 0);
    lua_pop(L, 1);
}

static void
title_changed_cb(WebKitWebView *v, WebKitWebFrame *f, const gchar *title, widget_t *w)
{
    (void) f;
    (void) v;
    (void) title;

    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "title-changed", 0, 0);
    lua_pop(L, 1);
}

static void
load_start_cb(WebKitWebView *v, WebKitWebFrame *f, widget_t *w)
{
    (void) v;
    (void) f;

    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "load-start", 0, 0);
    lua_pop(L, 1);
}

inline static void
update_uri(GtkWidget *view, const gchar *uri, widget_t *w)
{
    /* return if uri has not changed */
    if (!g_strcmp0(uri, g_object_get_data(G_OBJECT(view), "uri")))
        return;

    g_object_set_data_full(G_OBJECT(view), "uri", g_strdup(uri), g_free);
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "property::uri", 0, 0);
    lua_pop(L, 1);
}

static void
load_commit_cb(WebKitWebView *v, WebKitWebFrame *f, widget_t *w)
{
    update_uri(GTK_WIDGET(v), webkit_web_frame_get_uri(f), w);
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "load-commit", 0, 0);
    lua_pop(L, 1);
}

static void
load_finish_cb(WebKitWebView *v, WebKitWebFrame *f, widget_t *w)
{
    update_uri(GTK_WIDGET(v), webkit_web_frame_get_uri(f), w);
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "load-finish", 0, 0);
    lua_pop(L, 1);
}

static gboolean
mime_type_decision_cb(WebKitWebView *v, WebKitWebFrame *f,
        WebKitNetworkRequest *r, gchar *mime, WebKitWebPolicyDecision *pd,
        widget_t *w)
{
    (void) v;
    (void) f;
    lua_State *L = globalconf.L;
    const gchar *uri = webkit_network_request_get_uri(r);
    gint ret;

    luaH_object_push(L, w->ref);
    lua_pushstring(L, uri);
    lua_pushstring(L, mime);
    ret = luaH_object_emit_signal(L, -3, "mime-type-decision", 2, 1);

    if (ret && !luaH_checkboolean(L, -1))
        /* User responded with false, ignore request */
        webkit_web_policy_decision_ignore(pd);
    else if (!webkit_web_view_can_show_mime_type(v, mime))
        webkit_web_policy_decision_download(pd);
    else
        webkit_web_policy_decision_use(pd);

    lua_pop(L, ret + 1);
    return TRUE;
}

static gboolean
download_request_cb(WebKitWebView *v, GObject *dl, widget_t *w)
{
    (void) v;
    const gchar *uri = webkit_download_get_uri((WebKitDownload *) dl);
    const gchar *filename = webkit_download_get_suggested_filename((WebKitDownload *) dl);

    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    lua_pushstring(L, uri);
    lua_pushstring(L, filename);
    luaH_object_emit_signal(L, -3, "download-request", 2, 0);
    lua_pop(L, 1);

    return FALSE;
}

static void
link_hover_cb(WebKitWebView *view, const char *t, const gchar *link, widget_t *w)
{
    (void) t;
    lua_State *L = globalconf.L;
    GObject *ws = G_OBJECT(view);
    gchar *last_hover = g_object_get_data(ws, "hovered-uri");

    /* links are identical, do nothing */
    if (last_hover && !g_strcmp0(last_hover, link))
        return;

    luaH_object_push(L, w->ref);

    if (last_hover) {
        lua_pushstring(L, last_hover);
        g_object_set_data(ws, "hovered-uri", NULL);
        luaH_object_emit_signal(L, -2, "link-unhover", 1, 0);
    }

    if (link) {
        lua_pushstring(L, link);
        g_object_set_data_full(ws, "hovered-uri", g_strdup(link), g_free);
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
static gboolean
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

    luaH_object_push(L, w->ref);
    lua_pushstring(L, uri);
    ret = luaH_object_emit_signal(L, -2, "navigation-request", 1, 1);

    if (ret && !luaH_checkboolean(L, -1))
        /* User responded with false, do not continue navigation request */
        webkit_web_policy_decision_ignore(p);
    else
        webkit_web_policy_decision_use(p);

    lua_pop(L, ret + 1);
    return TRUE;
}

inline static gint
push_adjustment_values(lua_State *L, GtkAdjustment *adjustment)
{
    gdouble view_size = gtk_adjustment_get_page_size(adjustment);
    gdouble value = gtk_adjustment_get_value(adjustment);
    gdouble max = gtk_adjustment_get_upper(adjustment) - view_size;
    lua_pushnumber(L, value);
    lua_pushnumber(L, (max < 0 ? 0 : max));
    lua_pushnumber(L, view_size);
    return 3;
}

static gint
luaH_webview_get_vscroll(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    GtkAdjustment *adjustment = gtk_scrolled_window_get_vadjustment(GTK_SCROLLED_WINDOW(w->widget));
    return push_adjustment_values(L, adjustment);
}

static gint
luaH_webview_get_hscroll(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    GtkAdjustment *adjustment = gtk_scrolled_window_get_hadjustment(GTK_SCROLLED_WINDOW(w->widget));
    return push_adjustment_values(L, adjustment);
}

inline static void
set_adjustment(GtkAdjustment *adjustment, gdouble new)
{
    gdouble view_size = gtk_adjustment_get_page_size(adjustment);
    gdouble max = gtk_adjustment_get_upper(adjustment) - view_size;
    gtk_adjustment_set_value(adjustment, ((new < 0 ? 0 : new) > max ? max : new));
}

static gint
luaH_webview_set_scroll_vert(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    gdouble value = (gdouble) luaL_checknumber(L, 2);
    GtkAdjustment *adjustment = gtk_scrolled_window_get_vadjustment(GTK_SCROLLED_WINDOW(w->widget));
    set_adjustment(adjustment, value);
    return 0;
}

static gint
luaH_webview_set_scroll_horiz(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    gdouble value = (gdouble) luaL_checknumber(L, 2);
    GtkAdjustment *adjustment = gtk_scrolled_window_get_hadjustment(GTK_SCROLLED_WINDOW(w->widget));
    set_adjustment(adjustment, value);
    return 0;
}

static gint
luaH_webview_go_back(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    gint steps = (gint) luaL_checknumber(L, 2);
    GtkWidget *view = GTK_WIDGET(g_object_get_data(G_OBJECT(w->widget), "webview"));
    webkit_web_view_go_back_or_forward(WEBKIT_WEB_VIEW(view), steps * -1);
    return 0;
}

static gint
luaH_webview_go_forward(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    gint steps = (gint) luaL_checknumber(L, 2);
    GtkWidget *view = GTK_WIDGET(g_object_get_data(G_OBJECT(w->widget), "webview"));
    webkit_web_view_go_back_or_forward(WEBKIT_WEB_VIEW(view), steps);
    return 0;
}

static gint
luaH_webview_search(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    WebKitWebView *view = WEBKIT_WEB_VIEW(GTK_WIDGET(g_object_get_data(G_OBJECT(w->widget), "webview")));
    const gchar *text = luaL_checkstring(L, 2);
    gboolean case_sensitive = luaH_checkboolean(L, 3);
    gboolean forward = luaH_checkboolean(L, 4);
    gboolean wrap = luaH_checkboolean(L, 5);

    webkit_web_view_unmark_text_matches(view);
    webkit_web_view_search_text(view, text, case_sensitive, forward, wrap);
    webkit_web_view_mark_text_matches(view, text, case_sensitive, 0);
    webkit_web_view_set_highlight_text_matches(view, TRUE);
    return 0;
}

static gint
luaH_webview_clear_search(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    WebKitWebView *view = WEBKIT_WEB_VIEW(GTK_WIDGET(g_object_get_data(G_OBJECT(w->widget), "webview")));
    webkit_web_view_unmark_text_matches(view);
    return 0;
}

inline static GObject*
get_settings_object(GtkWidget *view, property_value_scope scope)
{
    switch (scope) {
      case SETTINGS:
        return G_OBJECT(webkit_web_view_get_settings(WEBKIT_WEB_VIEW(view)));
      case WEBKITVIEW:
        return G_OBJECT(view);
      case SOUPSESSION:
        return G_OBJECT(Soup.session);
      default:
        break;
    }
    return NULL;
}

static gint
luaH_webview_get_prop(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    const gchar *prop = luaL_checkstring(L, 2);
    GtkWidget *view = GTK_WIDGET(g_object_get_data(G_OBJECT(w->widget), "webview"));
    GObject *ws;
    property_tmp_values tmp;
    SoupURI *u;

    for (guint i = 0; i < LENGTH(properties); i++) {
        if (g_strcmp0(properties[i].name, prop))
            continue;

        ws = get_settings_object(view, properties[i].scope);

        switch(properties[i].type) {
          case BOOL:
            g_object_get(ws, prop, &tmp.b, NULL);
            lua_pushboolean(L, tmp.b);
            return 1;

          case CHAR:
            g_object_get(ws, prop, &tmp.c, NULL);
            lua_pushstring(L, tmp.c);
            g_free(tmp.c);
            return 1;

          case INT:
            g_object_get(ws, prop, &tmp.i, NULL);
            lua_pushnumber(L, tmp.i);
            return 1;

          case FLOAT:
            g_object_get(ws, prop, &tmp.f, NULL);
            lua_pushnumber(L, tmp.f);
            return 1;

          case DOUBLE:
            g_object_get(ws, prop, &tmp.d, NULL);
            lua_pushnumber(L, tmp.d);
            return 1;

          case URI:
            g_object_get(ws, prop, &u, NULL);
            tmp.c = soup_uri_to_string(u, 0);
            lua_pushstring(L, tmp.c);
            soup_uri_free(u);
            g_free(tmp.c);
            return 1;

          default:
            warn("unknown property type for: %s", properties[i].name);
            break;
        }
    }
    warn("unknown property: %s", prop);
    return 0;
}

static gint
luaH_webview_set_prop(lua_State *L)
{
    size_t len;
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    const gchar *prop = luaL_checklstring(L, 2, &len);
    GtkWidget *view = g_object_get_data(G_OBJECT(w->widget), "webview");
    GObject *ws;
    property_tmp_values tmp;
    SoupURI *u;

    for (guint i = 0; i < LENGTH(properties); i++) {
        if (g_strcmp0(properties[i].name, prop))
            continue;

        if (!properties[i].writable) {
            warn("attempt to set read-only property: %s", prop);
            return 0;
        }

        ws = get_settings_object(view, properties[i].scope);

        switch(properties[i].type) {
          case BOOL:
            tmp.b = luaH_checkboolean(L, 3);
            g_object_set(ws, prop, tmp.b, NULL);
            return 0;

          case CHAR:
            tmp.c = (gchar*) luaL_checklstring(L, 3, &len);
            g_object_set(ws, prop, tmp.c, NULL);
            return 0;

          case INT:
            tmp.i = (gint) luaL_checknumber(L, 3);
            g_object_set(ws, prop, tmp.i, NULL);
            return 0;

          case FLOAT:
            tmp.f = (gfloat) luaL_checknumber(L, 3);
            g_object_set(ws, prop, tmp.f, NULL);
            return 0;

          case DOUBLE:
            tmp.d = (gdouble) luaL_checknumber(L, 3);
            g_object_set(ws, prop, tmp.d, NULL);
            return 0;

          case URI:
            tmp.c = (gchar*) luaL_checkstring(L, 3);
            u = soup_uri_new(tmp.c);
            if (SOUP_URI_VALID_FOR_HTTP(u))
              g_object_set(ws, prop, u, NULL);
            else
              luaL_error(L, "cannot parse uri: %s", tmp.c);
            soup_uri_free(u);
            return 0;

          default:
            warn("unknown property type for: %s", properties[i].name);
            break;
        }
    }
    warn("unknown property: %s", prop);
    return 0;
}

static gint
luaH_webview_loading(lua_State *L)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    GtkWidget *view = g_object_get_data(G_OBJECT(w->widget), "webview");
    WebKitLoadStatus s;
    g_object_get(G_OBJECT(view), "load-status", &s, NULL);
    switch (s) {
      case WEBKIT_LOAD_PROVISIONAL:
      case WEBKIT_LOAD_COMMITTED:
      case WEBKIT_LOAD_FIRST_VISUALLY_NON_EMPTY_LAYOUT:
        lua_pushboolean(L, TRUE);
        break;

      default:
        lua_pushboolean(L, FALSE);
        break;
    }
    return 1;
}

void
show_scrollbars(widget_t *w, gboolean show)
{
    GtkWidget *view = g_object_get_data(G_OBJECT(w->widget), "webview");
    WebKitWebFrame *mf = webkit_web_view_get_main_frame(WEBKIT_WEB_VIEW(view));
    gulong id = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(view), "hide_handler_id"));

    if (show) {
        if (id)
            g_signal_handler_disconnect((gpointer) mf, id);
        gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(w->widget), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
        id = 0;
    } else if (!id) {
        gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(w->widget), GTK_POLICY_NEVER, GTK_POLICY_NEVER);
        id = g_signal_connect(G_OBJECT(mf), "scrollbars-policy-changed", G_CALLBACK(true_cb), NULL);
    }
    g_object_set_data(G_OBJECT(view), "hide_handler_id", GINT_TO_POINTER(id));
}

static gint
luaH_webview_index(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    GtkWidget *view = g_object_get_data(G_OBJECT(w->widget), "webview");

    switch(token)
    {
      case L_TK_DESTROY:
        lua_pushcfunction(L, luaH_widget_destroy);
        return 1;

      case L_TK_GET_SCROLL_VERT:
        lua_pushcfunction(L, luaH_webview_get_vscroll);
        return 1;

      case L_TK_GET_SCROLL_HORIZ:
        lua_pushcfunction(L, luaH_webview_get_hscroll);
        return 1;

      case L_TK_SET_SCROLL_VERT:
        lua_pushcfunction(L, luaH_webview_set_scroll_vert);
        return 1;

      case L_TK_SET_SCROLL_HORIZ:
        lua_pushcfunction(L, luaH_webview_set_scroll_horiz);
        return 1;

      case L_TK_EVAL_JS:
        lua_pushcfunction(L, luaH_webview_eval_js);
        return 1;

      case L_TK_SEARCH:
        lua_pushcfunction(L, luaH_webview_search);
        return 1;

      case L_TK_CLEAR_SEARCH:
        lua_pushcfunction(L, luaH_webview_clear_search);
        return 1;

      case L_TK_SET_PROP:
        lua_pushcfunction(L, luaH_webview_set_prop);
        return 1;

      case L_TK_GET_PROP:
        lua_pushcfunction(L, luaH_webview_get_prop);
        return 1;

      case L_TK_HOVERED_URI:
        lua_pushstring(L, g_object_get_data(G_OBJECT(view), "hovered-uri"));
        return 1;

      case L_TK_URI:
        lua_pushstring(L, g_object_get_data(G_OBJECT(view), "uri"));
        return 1;

      case L_TK_SHOW:
        lua_pushcfunction(L, luaH_widget_show);
        return 1;

      case L_TK_HIDE:
        lua_pushcfunction(L, luaH_widget_hide);
        return 1;

      case L_TK_FOCUS:
        lua_pushcfunction(L, luaH_widget_focus);
        return 1;

      case L_TK_LOADING:
        lua_pushcfunction(L, luaH_webview_loading);
        return 1;

      case L_TK_GO_BACK:
        lua_pushcfunction(L, luaH_webview_go_back);
        return 1;

      case L_TK_GO_FORWARD:
        lua_pushcfunction(L, luaH_webview_go_forward);
        return 1;

      default:
        warn("unknown property: %s", luaL_checkstring(L, 2));
        break;
    }

    return 0;
}

/* The __newindex method for the webview object */
static gint
luaH_webview_newindex(lua_State *L, luakit_token_t token)
{
    size_t len;
    widget_t *w = luaH_checkudata(L, 1, &widget_class);
    GtkWidget *view = g_object_get_data(G_OBJECT(w->widget), "webview");
    gchar *uri;

    switch(token)
    {
      case L_TK_URI:
        uri = (gchar*) luaL_checklstring(L, 3, &len);
        uri = g_strrstr(uri, "://") ? g_strdup(uri) :
            g_strdup_printf("http://%s", uri);
        webkit_web_view_load_uri(WEBKIT_WEB_VIEW(view), uri);
        g_object_set_data_full(G_OBJECT(view), "uri", uri, g_free);
        break;

      case L_TK_SHOW_SCROLLBARS:
        show_scrollbars(w, luaH_checkboolean(L, 3));
        return 0;

      default:
        warn("unknown property: %s", luaL_checkstring(L, 2));
        return 0;
    }

    return luaH_object_emit_property_signal(L, 1);
}

static gboolean
expose_cb(GtkWidget *widget, GdkEventExpose *e, widget_t *w)
{
    (void) e;
    (void) widget;
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "expose", 0, 0);
    lua_pop(L, 1);
    return FALSE;
}

static gboolean
wv_button_press_cb(GtkWidget *view, GdkEventButton *event, widget_t *w)
{
    if((event->type != GDK_BUTTON_PRESS) || (event->button != 1))
        return FALSE;

    /* get webview hit context */
    WebKitHitTestResult *ht = webkit_web_view_get_hit_test_result(WEBKIT_WEB_VIEW(view), event);
    guint c;
    g_object_get(ht, "context", &c, NULL);
    gint context = (gint) c;

    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    /* raise "form-active" when a user clicks on a form field and raise
     * "root-active" when a user clicks elsewhere */
    if (context & WEBKIT_HIT_TEST_RESULT_CONTEXT_EDITABLE)
        luaH_object_emit_signal(L, -1, "form-active", 0, 0);
    else if (context & WEBKIT_HIT_TEST_RESULT_CONTEXT_DOCUMENT)
        luaH_object_emit_signal(L, -1, "root-active", 0, 0);
    lua_pop(L, 1);
    return FALSE;
}

static void
webview_destructor(widget_t *w)
{
    GtkWidget *view = g_object_get_data(G_OBJECT(w->widget), "webview");
    gtk_widget_destroy(GTK_WIDGET(view));
    gtk_widget_destroy(GTK_WIDGET(w->widget));
}

widget_t *
widget_webview(widget_t *w)
{
    w->index = luaH_webview_index;
    w->newindex = luaH_webview_newindex;
    w->destructor = webview_destructor;

    /* init soup session & cookies handling */
    if (!Soup.session) {
        Soup.session = webkit_get_default_session();
        gchar *cookie_file = g_build_filename(globalconf.base_data_directory, "cookies.txt", NULL);
        Soup.cookiejar = soup_cookie_jar_text_new(cookie_file, FALSE);
        soup_session_add_feature(Soup.session, (SoupSessionFeature*) Soup.cookiejar);
        g_free(cookie_file);
    }

    GtkWidget *view = webkit_web_view_new();
    w->widget = gtk_scrolled_window_new(NULL, NULL);
    g_object_set_data(G_OBJECT(w->widget), "widget", w);
    g_object_set_data(G_OBJECT(w->widget), "webview", view);
    gtk_container_add(GTK_CONTAINER(w->widget), view);

    show_scrollbars(w, TRUE);

    /* connect webview signals */
    g_object_connect((GObject*)view,
      "signal::button-press-event",                   (GCallback)wv_button_press_cb,     w,
      "signal::expose-event",                         (GCallback)expose_cb,              w,
      "signal::focus-in-event",                       (GCallback)focus_cb,               w,
      "signal::focus-out-event",                      (GCallback)focus_cb,               w,
      "signal::hovering-over-link",                   (GCallback)link_hover_cb,          w,
      "signal::key-press-event",                      (GCallback)key_press_cb,           w,
      "signal::load-committed",                       (GCallback)load_commit_cb,         w,
      "signal::load-finished",                        (GCallback)load_finish_cb,         w,
      "signal::load-progress-changed",                (GCallback)progress_cb,            w,
      "signal::load-started",                         (GCallback)load_start_cb,          w,
      "signal::navigation-policy-decision-requested", (GCallback)navigation_decision_cb, w,
      "signal::parent-set",                           (GCallback)parent_set_cb,          w,
      "signal::title-changed",                        (GCallback)title_changed_cb,       w,
      "signal::download-requested",                   (GCallback)download_request_cb,    w,
      "signal::mime-type-policy-decision-requested",  (GCallback)mime_type_decision_cb,  w,
      NULL);

    /* setup */
    gtk_widget_show(view);
    gtk_widget_show(w->widget);

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
