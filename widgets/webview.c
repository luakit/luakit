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

#include "globalconf.h"
#include "luah.h"
#include "widgets/common.h"
#include "classes/download.h"
#include <JavaScriptCore/JavaScript.h>
#include <webkit/webkit.h>
#include <libsoup/soup-gnome.h>

#include "math.h"

GPtrArray *all_views = NULL;

static struct {
    SoupSession   *session;
    SoupCookieJar *cookiejar;
} Soup = { NULL, NULL };

static struct {
    GSList *refs;
    GSList *items;
} last_popup = { NULL, NULL };

typedef enum {
    BOOL,
    CHAR,
    INT,
    FLOAT,
    DOUBLE,
    URI,
} property_value_t;

typedef enum {
    SETTINGS,
    WEBKITVIEW,
    SOUPSESSION,
    COOKIEJAR,
} property_scope;

typedef union {
    gchar    *c;
    gboolean  b;
    gdouble   d;
    gfloat    f;
    gint      i;
} temp_value_t;

GHashTable *properties = NULL;

typedef struct {
    const gchar      *name;
    property_value_t type;
    property_scope   scope;
    gboolean         writable;
    const gchar      *signame;
} property_t;

property_t properties_table[] = {
  { "accept-language",                              CHAR,   SOUPSESSION, TRUE,  NULL },
  { "accept-language-auto",                         BOOL,   SOUPSESSION, TRUE,  NULL },
  { "accept-policy",                                INT,    COOKIEJAR,   TRUE,  NULL },
  { "auto-load-images",                             BOOL,   SETTINGS,    TRUE,  NULL },
  { "auto-resize-window",                           BOOL,   SETTINGS,    TRUE,  NULL },
  { "auto-shrink-images",                           BOOL,   SETTINGS,    TRUE,  NULL },
  { "cursive-font-family",                          CHAR,   SETTINGS,    TRUE,  NULL },
  { "custom-encoding",                              CHAR,   WEBKITVIEW,  TRUE,  NULL },
  { "default-encoding",                             CHAR,   SETTINGS,    TRUE,  NULL },
  { "default-font-family",                          CHAR,   SETTINGS,    TRUE,  NULL },
  { "default-font-size",                            INT,    SETTINGS,    TRUE,  NULL },
  { "default-monospace-font-size",                  INT,    SETTINGS,    TRUE,  NULL },
  { "editable",                                     BOOL,   WEBKITVIEW,  TRUE,  NULL },
  { "enable-caret-browsing",                        BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-default-context-menu",                  BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-developer-extras",                      BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-dom-paste",                             BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-file-access-from-file-uris",            BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-html5-database",                        BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-html5-local-storage",                   BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-java-applet",                           BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-offline-web-application-cache",         BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-page-cache",                            BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-plugins",                               BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-private-browsing",                      BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-scripts",                               BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-site-specific-quirks",                  BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-spatial-navigation",                    BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-spell-checking",                        BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-universal-access-from-file-uris",       BOOL,   SETTINGS,    TRUE,  NULL },
  { "enable-xss-auditor",                           BOOL,   SETTINGS,    TRUE,  NULL },
  { "encoding",                                     CHAR,   WEBKITVIEW,  FALSE, NULL },
  { "enforce-96-dpi",                               BOOL,   SETTINGS,    TRUE,  NULL },
  { "fantasy-font-family",                          CHAR,   SETTINGS,    TRUE,  NULL },
  { "full-content-zoom",                            BOOL,   WEBKITVIEW,  TRUE,  NULL },
  { "icon-uri",                                     CHAR,   WEBKITVIEW,  FALSE, NULL },
  { "idle-timeout",                                 INT,    SOUPSESSION, TRUE,  NULL },
  { "javascript-can-access-clipboard",              BOOL,   SETTINGS,    TRUE,  NULL },
  { "javascript-can-open-windows-automatically",    BOOL,   SETTINGS,    TRUE,  NULL },
  { "max-conns",                                    INT,    SOUPSESSION, TRUE,  NULL },
  { "max-conns-per-host",                           INT,    SOUPSESSION, TRUE,  NULL },
  { "minimum-font-size",                            INT,    SETTINGS,    TRUE,  NULL },
  { "minimum-logical-font-size",                    INT,    SETTINGS,    TRUE,  NULL },
  { "monospace-font-family",                        CHAR,   SETTINGS,    TRUE,  NULL },
  { "print-backgrounds",                            BOOL,   SETTINGS,    TRUE,  NULL },
  { "progress",                                     DOUBLE, WEBKITVIEW,  FALSE, NULL },
  { "proxy-uri",                                    URI,    SOUPSESSION, TRUE,  NULL },
  { "resizable-text-areas",                         BOOL,   SETTINGS,    TRUE,  NULL },
  { "sans-serif-font-family",                       CHAR,   SETTINGS,    TRUE,  NULL },
  { "serif-font-family",                            CHAR,   SETTINGS,    TRUE,  NULL },
  { "spell-checking-languages",                     CHAR,   SETTINGS,    TRUE,  NULL },
  { "ssl-ca-file",                                  CHAR,   SOUPSESSION, TRUE,  NULL },
  { "ssl-strict",                                   BOOL,   SOUPSESSION, TRUE,  NULL },
  { "tab-key-cycles-through-elements",              BOOL,   SETTINGS,    TRUE,  NULL },
  { "timeout",                                      INT,    SOUPSESSION, TRUE,  NULL },
  { "title",                                        CHAR,   WEBKITVIEW,  FALSE, NULL },
  { "transparent",                                  BOOL,   WEBKITVIEW,  TRUE,  NULL },
  { "use-ntlm",                                     BOOL,   SOUPSESSION, TRUE,  NULL },
  { "user-agent",                                   CHAR,   SETTINGS,    TRUE,  NULL },
  { "user-stylesheet-uri",                          CHAR,   SETTINGS,    TRUE,  NULL },
  { "zoom-level",                                   FLOAT,  WEBKITVIEW,  TRUE,  NULL },
  { "zoom-step",                                    FLOAT,  SETTINGS,    TRUE,  NULL },
  { NULL,                                           0,      0,           0,     NULL },
};

static void
webview_init_properties() {
    properties = g_hash_table_new(g_str_hash, g_str_equal);
    for (property_t *p = properties_table; p->name; p++) {
        /* pre-compile "property::name" signals for each property */
        if (!p->signame) p->signame = g_strdup_printf("property::%s", p->name);
        g_hash_table_insert(properties, (gpointer) p->name, (gpointer) p);
    }
}

static JSValueRef
webview_registered_function_callback(JSContextRef context, JSObjectRef fun, JSObjectRef thisObject,
        size_t argumentCount, const JSValueRef *arguments, JSValueRef *exception) {
    (void) thisObject;
    (void) argumentCount;
    (void) arguments;

    lua_State *L = globalconf.L;
    gpointer ref = JSObjectGetPrivate(fun);
    // get function
    luaH_object_push(L, ref);
    // call function
    int ret = lua_pcall(L, 0, 0, 0);
    // handle errors
    if (ret != 0) {
        const char *exn_cstring = luaL_checkstring(L, -1);
        lua_pop(L, 1);
        JSStringRef exn_js_string = JSStringCreateWithUTF8CString(exn_cstring);
        JSValueRef exn_js_value = JSValueMakeString(context, exn_js_string);
        *exception = JSValueToObject(context, exn_js_value, NULL);
        JSStringRelease(exn_js_string);
    }
    return JSValueMakeUndefined(context);
}

static void
webview_collect_registered_function(JSObjectRef obj) {
    lua_State *L = globalconf.L;
    gpointer ref = JSObjectGetPrivate(obj);
    luaH_object_unref(L, ref);
}

static void
webview_register_function(WebKitWebFrame *frame, const gchar *name, gpointer ref) {
    JSGlobalContextRef context = webkit_web_frame_get_global_context(frame);
    JSStringRef js_name = JSStringCreateWithUTF8CString(name);
    // prepare callback function
    JSClassDefinition def = kJSClassDefinitionEmpty;
    def.callAsFunction = webview_registered_function_callback;
    def.className = g_strdup(name);
    def.finalize = webview_collect_registered_function;
    JSClassRef class = JSClassCreate(&def);
    JSObjectRef fun = JSObjectMake(context, class, ref);
    // register with global object
    JSObjectRef global = JSContextGetGlobalObject(context);
    JSObjectSetProperty(context, global, js_name, fun, kJSPropertyAttributeDontDelete | kJSPropertyAttributeReadOnly, NULL);
    // release strings
    JSStringRelease(js_name);
    JSClassRelease(class);
}

static const gchar*
webview_eval_js(WebKitWebFrame *frame, const gchar *script, const gchar *file) {
    JSGlobalContextRef context;
    JSObjectRef globalobject;
    JSStringRef js_file;
    JSStringRef js_script;
    JSValueRef js_result;
    JSValueRef js_exc = NULL;
    JSStringRef js_result_string;
    GString *result = g_string_new(NULL);
    size_t js_result_size;

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

        g_printf("Exception occured while executing script:\n");

        /* Print file */
        prop = JSStringCreateWithUTF8CString("sourceURL");
        val = JSValueToStringCopy(context, JSObjectGetProperty(context, exc, prop, NULL), NULL);
        size = JSStringGetMaximumUTF8CStringSize(val);
        if(size) {
            char cstr[size];
            JSStringGetUTF8CString(val, cstr, size);
            g_printf("At %s", cstr);
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
            g_printf(":%s: ", cstr);
        }
        JSStringRelease(prop);
        JSStringRelease(val);

        /* Print message */
        val = JSValueToStringCopy(context, exc, NULL);
        size = JSStringGetMaximumUTF8CStringSize(val);
        if(size) {
            char cstr[size];
            JSStringGetUTF8CString(val, cstr, size);
            g_printf("%s\n", cstr);
        }
        JSStringRelease(val);
    }

    /* cleanup */
    JSStringRelease(js_script);
    JSStringRelease(js_file);

    return g_string_free(result, FALSE);
}

static gint
luaH_webview_load_string(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    WebKitWebView *view = WEBKIT_WEB_VIEW(g_object_get_data(G_OBJECT(w->widget), "webview"));
    const char *string = luaL_checkstring(L, 2);
    const char *base_uri = luaL_checkstring(L, 3);
    WebKitWebFrame *frame = webkit_web_view_get_main_frame(view);
    webkit_web_frame_load_alternate_string(frame, string, base_uri, base_uri);
    return 0;
}

static gint
luaH_webview_register_function(lua_State *L)
{
    WebKitWebFrame *frame = NULL;
    widget_t *w = luaH_checkwidget(L, 1);
    WebKitWebView *view = WEBKIT_WEB_VIEW(g_object_get_data(G_OBJECT(w->widget), "webview"));
    const gchar *name = luaL_checkstring(L, 2);
    gpointer ref = luaH_object_ref(L, 3);

    /* Check if function should be registered on currently focused frame */
    if (lua_gettop(L) >= 4 && luaH_checkboolean(L, 4))
        frame = webkit_web_view_get_focused_frame(view);
    /* Fall back on main frame */
    if (!frame)
        frame = webkit_web_view_get_main_frame(WEBKIT_WEB_VIEW(view));

    /* register function */
    webview_register_function(frame, name, ref);
    return 0;
}

static gint
luaH_webview_eval_js(lua_State *L)
{
    WebKitWebFrame *frame = NULL;
    widget_t *w = luaH_checkwidget(L, 1);
    WebKitWebView *view = WEBKIT_WEB_VIEW(g_object_get_data(G_OBJECT(w->widget), "webview"));
    const gchar *script = luaL_checkstring(L, 2);
    const gchar *filename = luaL_checkstring(L, 3);

    /* Check if js should be run on currently focused frame */
    if (lua_gettop(L) >= 4 && luaH_checkboolean(L, 4))
        frame = webkit_web_view_get_focused_frame(view);
    /* Fall back on main frame */
    if (!frame)
        frame = webkit_web_view_get_main_frame(WEBKIT_WEB_VIEW(view));

    /* evaluate javascript script and push return result onto lua stack */
    const gchar *result = webview_eval_js(frame, script, filename);
    lua_pushstring(L, result);
    return 1;
}

static void
notify_cb(WebKitWebView *v, GParamSpec *ps, widget_t *w)
{
    (void) v;
    property_t *p;
    /* emit webview property signal if found in properties table */
    if ((p = g_hash_table_lookup(properties, ps->name))) {
        lua_State *L = globalconf.L;
        luaH_object_push(L, w->ref);
        luaH_object_emit_signal(L, -1, p->signame, 0, 0);
        lua_pop(L, 1);
    }
}

static void
soup_notify_cb(SoupSession *s, GParamSpec *ps, gpointer *d)
{
    (void) s;
    (void) d;
    property_t *p;
    /* emit soup property signal on all webview widgets if found
       in properties table */
    if ((p = g_hash_table_lookup(properties, ps->name))) {
        lua_State *L = globalconf.L;
        widget_t *w;
        for (guint i = 0; i < all_views->len; i++) {
            w = all_views->pdata[i];
            luaH_object_push(L, w->ref);
            luaH_object_emit_signal(L, -1, p->signame, 0, 0);
            lua_pop(L, 1);
        }
    }
}

static void
update_uri(widget_t *w, const gchar *new)
{
    GtkWidget *view = g_object_get_data(G_OBJECT(w->widget), "webview");
    const gchar *old = (gchar*) g_object_get_data(G_OBJECT(view), "uri");

    if (!new)
        new = webkit_web_view_get_uri(WEBKIT_WEB_VIEW(view));

    /* uris are the same, do nothing */
    if (g_strcmp0(old, new)) {
        g_object_set_data_full(G_OBJECT(view), "uri", g_strdup(new), g_free);
        lua_State *L = globalconf.L;
        luaH_object_push(L, w->ref);
        luaH_object_emit_signal(L, -1, "property::uri", 0, 0);
        lua_pop(L, 1);
    }
}

static void
notify_load_status_cb(WebKitWebView *v, GParamSpec *ps, widget_t *w)
{
    (void) ps;

    /* Get load status */
    WebKitLoadStatus status;
    g_object_get(G_OBJECT(v), "load-status", &status, NULL);

    /* get load status literal */
    gchar *name = NULL;
    switch (status) {

#define LT_CASE(a, l) case WEBKIT_LOAD_##a: name = l; break;
        LT_CASE(PROVISIONAL,                     "provisional")
        LT_CASE(COMMITTED,                       "committed")
        LT_CASE(FINISHED,                        "finished")
        LT_CASE(FIRST_VISUALLY_NON_EMPTY_LAYOUT, "first-visual")
        LT_CASE(FAILED,                          "failed")
#undef  LT_CASE

      default:
        warn("programmer error, unable to get load status literal");
        break;
    }

    /* update uri after redirects, etc */
    if ((status & WEBKIT_LOAD_COMMITTED) || (status & WEBKIT_LOAD_FINISHED))
        update_uri(w, NULL);

    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    lua_pushstring(L, name);
    luaH_object_emit_signal(L, -2, "load-status", 1, 0);
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
resource_request_starting_cb(WebKitWebView *v, WebKitWebFrame *f,
        WebKitWebResource *we, WebKitNetworkRequest *r, WebKitNetworkResponse *response,
        widget_t *w)
{
    (void) v;
    (void) f;
    (void) we;
    (void) f;
    (void) response;
    const gchar *uri = webkit_network_request_get_uri(r);
    lua_State *L = globalconf.L;
    gint ret;

    luaH_object_push(L, w->ref);
    lua_pushstring(L, uri);
    ret = luaH_object_emit_signal(L, -2, "resource-request-starting", 1, 1);

    if (ret && !luaH_checkboolean(L, -1))
        /* User responded with false, ignore request */
        webkit_network_request_set_uri(r, "about:blank");

    lua_pop(L, ret + 1);
    return TRUE;
}

static gboolean
new_window_decision_cb(WebKitWebView *v, WebKitWebFrame *f,
        WebKitNetworkRequest *r, WebKitWebNavigationAction *na,
        WebKitWebPolicyDecision *pd, widget_t *w)
{
    (void) v;
    (void) f;
    lua_State *L = globalconf.L;
    const gchar *uri = webkit_network_request_get_uri(r);
    gchar *reason = NULL;
    gint ret = 0;

    luaH_object_push(L, w->ref);
    lua_pushstring(L, uri);

    switch (webkit_web_navigation_action_get_reason(na)) {

#define NR_CASE(a, l) case WEBKIT_WEB_NAVIGATION_REASON_##a: reason = l; break;
        NR_CASE(LINK_CLICKED,     "link-clicked");
        NR_CASE(FORM_SUBMITTED,   "form-submitted");
        NR_CASE(BACK_FORWARD,     "back-forward");
        NR_CASE(RELOAD,           "reload");
        NR_CASE(FORM_RESUBMITTED, "form-resubmitted");
        NR_CASE(OTHER,            "other");
#undef  NR_CASE

      default:
        warn("programmer error, unable to get web navigation reason literal");
        break;
    }

    lua_pushstring(L, reason);
    ret = luaH_object_emit_signal(L, -3, "new-window-decision", 2, 1);

    /* User responded with true, meaning a decision was made
     * and the signal was handled */
    if (ret && luaH_checkboolean(L, -1))
    {
        webkit_web_policy_decision_ignore(pd);
        lua_pop(L, ret + 1);

        return TRUE;
    }

    lua_pop(L, ret + 1);

    /* proceed with default behaviour */
    return FALSE;
}

static WebKitWebView*
create_web_view_cb(WebKitWebView *v, WebKitWebFrame *f, widget_t *w)
{
    (void) v;
    (void) f;
    gint ret;
    gint top;
    WebKitWebView *view = NULL;
    widget_t *new;

    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    top = lua_gettop(L);
    ret = luaH_object_emit_signal(L, top, "create-web-view", 0, 1);
    if (ret && (new = luaH_checkwidget(L, top + 1)))
        view = WEBKIT_WEB_VIEW(g_object_get_data(G_OBJECT(new->widget), "webview"));
    lua_pop(L, ret + 1);
    return view;
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
luaH_adjustment_push_values(lua_State *L, GtkAdjustment *a)
{
    gdouble view_size = gtk_adjustment_get_page_size(a);
    gdouble value = gtk_adjustment_get_value(a);
    gdouble max = gtk_adjustment_get_upper(a) - view_size;
    lua_pushnumber(L, value);
    lua_pushnumber(L, (max < 0 ? 0 : max));
    lua_pushnumber(L, view_size);
    return 3;
}

static gint
luaH_webview_get_scroll_vert(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    GtkAdjustment *a = gtk_scrolled_window_get_vadjustment(GTK_SCROLLED_WINDOW(w->widget));
    return luaH_adjustment_push_values(L, a);
}

static gint
luaH_webview_get_scroll_horiz(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    GtkAdjustment *a = gtk_scrolled_window_get_hadjustment(GTK_SCROLLED_WINDOW(w->widget));
    return luaH_adjustment_push_values(L, a);
}

inline static void
adjustment_set(GtkAdjustment *a, gdouble new)
{
    gdouble view_size = gtk_adjustment_get_page_size(a);
    gdouble max = gtk_adjustment_get_upper(a) - view_size;
    gtk_adjustment_set_value(a, ((new < 0 ? 0 : new) > max ? max : new));
}

static gint
luaH_webview_set_scroll_vert(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gdouble value = (gdouble) luaL_checknumber(L, 2);
    GtkAdjustment *a = gtk_scrolled_window_get_vadjustment(GTK_SCROLLED_WINDOW(w->widget));
    adjustment_set(a, value);
    return 0;
}

static gint
luaH_webview_set_scroll_horiz(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gdouble value = (gdouble) luaL_checknumber(L, 2);
    GtkAdjustment *a = gtk_scrolled_window_get_hadjustment(GTK_SCROLLED_WINDOW(w->widget));
    adjustment_set(a, value);
    return 0;
}

static gint
luaH_webview_go_back(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gint steps = (gint) luaL_checknumber(L, 2);
    GtkWidget *view = GTK_WIDGET(g_object_get_data(G_OBJECT(w->widget), "webview"));
    webkit_web_view_go_back_or_forward(WEBKIT_WEB_VIEW(view), steps * -1);
    return 0;
}

static gint
luaH_webview_go_forward(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    gint steps = (gint) luaL_checknumber(L, 2);
    GtkWidget *view = GTK_WIDGET(g_object_get_data(G_OBJECT(w->widget), "webview"));
    webkit_web_view_go_back_or_forward(WEBKIT_WEB_VIEW(view), steps);
    return 0;
}

static gint
luaH_webview_get_view_source(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    GtkWidget *view = GTK_WIDGET(g_object_get_data(G_OBJECT(w->widget), "webview"));
    lua_pushboolean(L, webkit_web_view_get_view_source_mode(WEBKIT_WEB_VIEW(view)));
    return 1;
}

static gint
luaH_webview_set_view_source(lua_State *L)
{
    const gchar *uri;
    widget_t *w = luaH_checkwidget(L, 1);
    gboolean show = luaH_checkboolean(L, 2);
    GtkWidget *view = GTK_WIDGET(g_object_get_data(G_OBJECT(w->widget), "webview"));
    webkit_web_view_set_view_source_mode(WEBKIT_WEB_VIEW(view), show);
    if ((uri = webkit_web_view_get_uri(WEBKIT_WEB_VIEW(view))))
        webkit_web_view_load_uri(WEBKIT_WEB_VIEW(view), uri);
    return 0;
}

static gint
luaH_webview_reload(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    WebKitWebView *view = WEBKIT_WEB_VIEW(g_object_get_data(G_OBJECT(w->widget), "webview"));
    webkit_web_view_reload(view);
    return 0;
}

static gint
luaH_webview_reload_bypass_cache(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    WebKitWebView *view = WEBKIT_WEB_VIEW(g_object_get_data(G_OBJECT(w->widget), "webview"));
    webkit_web_view_reload_bypass_cache(view);
    return 0;
}

static gint
luaH_webview_search(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    WebKitWebView *view = WEBKIT_WEB_VIEW(GTK_WIDGET(g_object_get_data(G_OBJECT(w->widget), "webview")));
    const gchar *text = luaL_checkstring(L, 2);
    gboolean case_sensitive = luaH_checkboolean(L, 3);
    gboolean forward = luaH_checkboolean(L, 4);
    gboolean wrap = luaH_checkboolean(L, 5);

    webkit_web_view_unmark_text_matches(view);
    gboolean ret = webkit_web_view_search_text(view, text, case_sensitive, forward, wrap);
    if (ret) {
        webkit_web_view_mark_text_matches(view, text, case_sensitive, 0);
        webkit_web_view_set_highlight_text_matches(view, TRUE);
    }
    lua_pushboolean(L, ret);
    return 1;
}

static gint
luaH_webview_clear_search(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    WebKitWebView *view = WEBKIT_WEB_VIEW(GTK_WIDGET(g_object_get_data(G_OBJECT(w->widget), "webview")));
    webkit_web_view_unmark_text_matches(view);
    return 0;
}

inline static GObject*
get_settings_object(GtkWidget *view, property_t *p)
{
    switch (p->scope) {
      case SETTINGS:
        return G_OBJECT(webkit_web_view_get_settings(WEBKIT_WEB_VIEW(view)));
      case WEBKITVIEW:
        return G_OBJECT(view);
      case SOUPSESSION:
        return G_OBJECT(Soup.session);
      case COOKIEJAR:
        return G_OBJECT(Soup.cookiejar);
      default:
        break;
    }
    warn("programmer error: unknown settings scope for property: %s", p->name);
    return NULL;
}

static gint
luaH_webview_get_prop(lua_State *L)
{
    GObject *so;
    SoupURI *u;
    property_t *p;
    temp_value_t tmp;

    /* get webview widget */
    widget_t *w = luaH_checkwidget(L, 1);
    GtkWidget *view = GTK_WIDGET(g_object_get_data(G_OBJECT(w->widget), "webview"));

    /* get property struct */
    const gchar *name = luaL_checkstring(L, 2);
    if ((p = g_hash_table_lookup(properties, name))) {
        so = get_settings_object(view, p);

        switch(p->type) {
          case BOOL:
            g_object_get(so, p->name, &tmp.b, NULL);
            lua_pushboolean(L, tmp.b);
            return 1;

          case INT:
            g_object_get(so, p->name, &tmp.i, NULL);
            lua_pushnumber(L, tmp.i);
            return 1;

          case FLOAT:
            g_object_get(so, p->name, &tmp.f, NULL);
            lua_pushnumber(L, tmp.f);
            return 1;

          case DOUBLE:
            g_object_get(so, p->name, &tmp.d, NULL);
            lua_pushnumber(L, tmp.d);
            return 1;

          case CHAR:
            g_object_get(so, p->name, &tmp.c, NULL);
            lua_pushstring(L, tmp.c);
            g_free(tmp.c);
            return 1;

          case URI:
            g_object_get(so, p->name, &u, NULL);
            tmp.c = u ? soup_uri_to_string(u, 0) : NULL;
            lua_pushstring(L, tmp.c);
            if (u) soup_uri_free(u);
            g_free(tmp.c);
            return 1;

          default:
            warn("programmer error: unknown property type for: %s", p->name);
            break;
        }
    }
    warn("unknown property: %s", name);
    return 0;
}

static gint
luaH_webview_set_prop(lua_State *L)
{
    size_t len;
    GObject *so;
    SoupURI *u;
    property_t *p;
    temp_value_t tmp;

    /* get webview widget */
    widget_t *w = luaH_checkwidget(L, 1);
    GtkWidget *view = g_object_get_data(G_OBJECT(w->widget), "webview");

    /* get property struct */
    const gchar *name = luaL_checkstring(L, 2);
    if ((p = g_hash_table_lookup(properties, name))) {
        if (!p->writable) {
            warn("attempt to set read-only property: %s", p->name);
            return 0;
        }

        so = get_settings_object(view, p);
        switch(p->type) {
          case BOOL:
            tmp.b = luaH_checkboolean(L, 3);
            g_object_set(so, p->name, tmp.b, NULL);
            return 0;

          case INT:
            tmp.i = (gint) luaL_checknumber(L, 3);
            g_object_set(so, p->name, tmp.i, NULL);
            return 0;

          case FLOAT:
            tmp.f = (gfloat) luaL_checknumber(L, 3);
            g_object_set(so, p->name, tmp.f, NULL);
            return 0;

          case DOUBLE:
            tmp.d = (gdouble) luaL_checknumber(L, 3);
            g_object_set(so, p->name, tmp.d, NULL);
            return 0;

          case CHAR:
            tmp.c = (gchar*) luaL_checkstring(L, 3);
            g_object_set(so, p->name, tmp.c, NULL);
            return 0;

          case URI:
            tmp.c = (gchar*) luaL_checklstring(L, 3, &len);
            /* use http protocol if none specified */
            if (!len || g_strrstr(tmp.c, "://"))
                tmp.c = g_strdup(tmp.c);
            else
                tmp.c = g_strdup_printf("http://%s", tmp.c);
            u = soup_uri_new(tmp.c);
            if (!u || SOUP_URI_VALID_FOR_HTTP(u))
                g_object_set(so, p->name, u, NULL);
            else
                luaL_error(L, "cannot parse uri: %s", tmp.c);
            if (u) soup_uri_free(u);
            g_free(tmp.c);
            return 0;

          default:
            warn("programmer error: unknown property type for: %s", p->name);
            break;
        }
    }
    warn("unknown property: %s", name);
    return 0;
}

static gint
luaH_webview_loading(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
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

static gint
luaH_webview_stop(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    GtkWidget *view = g_object_get_data(G_OBJECT(w->widget), "webview");
    webkit_web_view_stop_loading(WEBKIT_WEB_VIEW(view));
    return 0;
}

/* check for trusted ssl certificate */
static gint
luaH_webview_ssl_trusted(lua_State *L)
{
    widget_t *w = luaH_checkwidget(L, 1);
    GtkWidget *view = g_object_get_data(G_OBJECT(w->widget), "webview");
    const gchar *uri = webkit_web_view_get_uri(WEBKIT_WEB_VIEW(view));
    if (uri && !strncmp(uri, "https", 5)) {
        WebKitWebFrame *frame = webkit_web_view_get_main_frame(WEBKIT_WEB_VIEW(view));
        WebKitWebDataSource *src = webkit_web_frame_get_data_source(frame);
        WebKitNetworkRequest *req = webkit_web_data_source_get_request(src);
        SoupMessage *soup_msg = webkit_network_request_get_message(req);
        lua_pushboolean(L, (soup_msg && (soup_message_get_flags(soup_msg)
            & SOUP_MESSAGE_CERTIFICATE_TRUSTED)) ? TRUE : FALSE);
        return 1;
    }
    /* return nil if not viewing https uri */
    return 0;
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
luaH_webview_push_history(lua_State *L, WebKitWebView *view)
{
    /* obtain the history list of the tab and get information about it */
    WebKitWebBackForwardList *bflist = webkit_web_back_forward_list_new_with_web_view(view);
    WebKitWebHistoryItem *item;
    gint backlen = webkit_web_back_forward_list_get_back_length(bflist);
    gint forwardlen = webkit_web_back_forward_list_get_forward_length(bflist);

    /* compose an overall table with the history list and the position thereof */
    lua_createtable(L, 0, 2);
    /* Set hist[index] = pos */
    lua_pushliteral(L, "index");
    lua_pushnumber(L, backlen + 1);
    lua_rawset(L, -3);

    /* create a table with the history items */
    lua_createtable(L, backlen + forwardlen + 1, 0);
    for(gint i = -backlen; i <= forwardlen; i++) {
        /* each individual history item is composed of a URL and a page title */
        item = webkit_web_back_forward_list_get_nth_item(bflist, i);
        lua_createtable(L, 0, 2);
        /* Set hist_item[uri] = uri */
        lua_pushliteral(L, "uri");
        lua_pushstring(L, item ? webkit_web_history_item_get_uri(item) : "about:blank");
        lua_rawset(L, -3);
        /* Set hist_item[title] = title */
        lua_pushliteral(L, "title");
        lua_pushstring(L, item ? webkit_web_history_item_get_title(item) : "");
        lua_rawset(L, -3);
        lua_rawseti(L, -2, backlen + i + 1);
    }

    /* Set hist[items] = hist_items_table */
    lua_pushliteral(L, "items");
    lua_insert(L, lua_gettop(L) - 1);
    lua_rawset(L, -3);
    return 1;
}

static void
webview_set_history(lua_State *L, WebKitWebView *view, gint idx)
{
    gint pos, bflen;
    WebKitWebBackForwardList *bflist;
    WebKitWebHistoryItem *item = NULL;
    gchar *uri = NULL;

    if(!lua_istable(L, idx))
        luaL_error(L, "invalid history table");

    /* get history items table */
    lua_pushliteral(L, "items");
    lua_rawget(L, idx);
    bflen = lua_objlen(L, -1);

    /* create new back-forward history list */
    bflist = webkit_web_back_forward_list_new_with_web_view(view);
    webkit_web_back_forward_list_clear(bflist);

    /* get position of current history item */
    lua_pushliteral(L, "index");
    lua_rawget(L, idx);
    pos = (gint)lua_tonumber(L, -1);
    /* load last item if out of range */
    pos = (pos < 1 || pos > bflen) ? 0 : pos - bflen;
    lua_pop(L, 1);

    /* now we actually set the history to the content of the list */
    for (gint i = 1; i <= bflen; i++) {
        lua_rawgeti(L, -1, i);
        lua_pushliteral(L, "title");
        lua_rawget(L, -2);
        lua_pushliteral(L, "uri");
        lua_rawget(L, -3);
        if (pos || i < bflen) {
            item = webkit_web_history_item_new_with_data(lua_tostring(L, -1), NONULL(lua_tostring(L, -2)));
            webkit_web_back_forward_list_add_item(bflist, item);
        } else
            uri = g_strdup(lua_tostring(L, -1));
        lua_pop(L, 3);
    }

    /* load last item */
    if (uri) {
        webkit_web_view_load_uri(view, uri);
        g_free(uri);

    /* load item in history */
    } else if (bflen && webkit_web_view_can_go_back_or_forward(view, pos)) {
        webkit_web_view_go_back_or_forward(view, pos);

    /* load "about:blank" on empty history list */
    } else
        webkit_web_view_load_uri(view, "about:blank");

    lua_pop(L, 1);
}

static gint
luaH_webview_index(lua_State *L, luakit_token_t token)
{
    widget_t *w = luaH_checkwidget(L, 1);
    GtkWidget *view = g_object_get_data(G_OBJECT(w->widget), "webview");
    temp_value_t tmp;

    switch(token)
    {
      LUAKIT_WIDGET_INDEX_COMMON

      /* push property methods */
      PF_CASE(GET_PROP,             luaH_webview_get_prop)
      PF_CASE(SET_PROP,             luaH_webview_set_prop)
      /* push scroll adjustment methods */
      PF_CASE(GET_SCROLL_HORIZ,     luaH_webview_get_scroll_horiz)
      PF_CASE(GET_SCROLL_VERT,      luaH_webview_get_scroll_vert)
      PF_CASE(SET_SCROLL_HORIZ,     luaH_webview_set_scroll_horiz)
      PF_CASE(SET_SCROLL_VERT,      luaH_webview_set_scroll_vert)
      /* push search methods */
      PF_CASE(CLEAR_SEARCH,         luaH_webview_clear_search)
      PF_CASE(SEARCH,               luaH_webview_search)
      /* push history navigation methods */
      PF_CASE(GO_BACK,              luaH_webview_go_back)
      PF_CASE(GO_FORWARD,           luaH_webview_go_forward)
      /* push misc webview methods */
      PF_CASE(EVAL_JS,              luaH_webview_eval_js)
      PF_CASE(REGISTER_FUNCTION,    luaH_webview_register_function)
      PF_CASE(LOAD_STRING,          luaH_webview_load_string)
      PF_CASE(LOADING,              luaH_webview_loading)
      PF_CASE(RELOAD,               luaH_webview_reload)
      PF_CASE(RELOAD_BYPASS_CACHE,  luaH_webview_reload_bypass_cache)
      PF_CASE(SSL_TRUSTED,          luaH_webview_ssl_trusted)
      PF_CASE(STOP,                 luaH_webview_stop)
      /* push source viewing methods */
      PF_CASE(GET_VIEW_SOURCE,      luaH_webview_get_view_source)
      PF_CASE(SET_VIEW_SOURCE,      luaH_webview_set_view_source)

      /* push string properties */
      PS_CASE(HOVERED_URI, g_object_get_data(G_OBJECT(view), "hovered-uri"))

      case L_TK_URI:
        tmp.c = g_object_get_data(G_OBJECT(view), "uri");
        lua_pushstring(L, tmp.c);
        return 1;

      case L_TK_HISTORY:
        return luaH_webview_push_history(L, WEBKIT_WEB_VIEW(view));

      default:
        break;
    }

    return 0;
}

static gchar*
parse_uri(const gchar *uri) {
    gchar *curdir, *filepath, *new;
    /* check for scheme or "about:blank" */
    if (g_strrstr(uri, "://") || !g_strcmp0(uri, "about:blank"))
        new = g_strdup(uri);
    /* check if uri points to a file */
    else if (file_exists(uri)) {
        if (g_path_is_absolute(uri))
            new = g_strdup_printf("file://%s", uri);
        else { /* make path absolute */
            curdir = g_get_current_dir();
            filepath = g_build_filename(curdir, uri, NULL);
            new = g_strdup_printf("file://%s", filepath);
            g_free(curdir);
            g_free(filepath);
        }
    /* default to http:// scheme */
    } else
        new = g_strdup_printf("http://%s", uri);
    return new;
}

/* The __newindex method for the webview object */
static gint
luaH_webview_newindex(lua_State *L, luakit_token_t token)
{
    size_t len;
    widget_t *w = luaH_checkwidget(L, 1);
    GtkWidget *view = g_object_get_data(G_OBJECT(w->widget), "webview");
    temp_value_t tmp;

    switch(token)
    {
      case L_TK_URI:
        tmp.c = parse_uri(luaL_checklstring(L, 3, &len));
        webkit_web_view_load_uri(WEBKIT_WEB_VIEW(view), tmp.c);
        update_uri(w, tmp.c);
        g_free(tmp.c);
        return 0;

      case L_TK_SHOW_SCROLLBARS:
        show_scrollbars(w, luaH_checkboolean(L, 3));
        break;

      case L_TK_HISTORY:
        webview_set_history(L, WEBKIT_WEB_VIEW(view), 3);
        break;

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

static gint
luaH_push_hit_test(lua_State *L, WebKitWebView *v, GdkEventButton *ev)
{
    /* get hit test */
    WebKitHitTestResult *h = webkit_web_view_get_hit_test_result(v, ev);
    guint c;
    g_object_get(h, "context", &c, NULL);

    /* create new table to store hit test context data */
    lua_newtable(L);
    const gchar *name;

#define HTR_CHECK(a, l)                             \
    if ((c & WEBKIT_HIT_TEST_RESULT_CONTEXT_##a)) { \
        name = l;                                   \
        lua_pushstring(L, name);                    \
        lua_pushboolean(L, TRUE);                   \
        lua_rawset(L, -3);                          \
    }

    /* add context items to table */
    HTR_CHECK(DOCUMENT,  "document")
    HTR_CHECK(LINK,      "link")
    HTR_CHECK(IMAGE,     "image")
    HTR_CHECK(MEDIA,     "media")
    HTR_CHECK(SELECTION, "selection")
    HTR_CHECK(EDITABLE,  "editable")

#undef HTR_CHECK

    return 1;
}


static gboolean
webview_button_cb(GtkWidget *view, GdkEventButton *ev, widget_t *w)
{
    gint ret;
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_modifier_table_push(L, ev->state);
    lua_pushinteger(L, ev->button);
    /* push webview hit test context */
    luaH_push_hit_test(L, WEBKIT_WEB_VIEW(view), ev);

    switch (ev->type) {
      case GDK_2BUTTON_PRESS:
        ret = luaH_object_emit_signal(L, -4, "button-double-click", 3, 1);
        break;
      case GDK_BUTTON_RELEASE:
        ret = luaH_object_emit_signal(L, -4, "button-release", 3, 1);
        break;
      default:
        ret = luaH_object_emit_signal(L, -4, "button-press", 3, 1);
        break;
    }

    /* User responded with TRUE, so do not propagate event any further */
    if (ret && luaH_checkboolean(L, -1)) {
        lua_pop(L, ret + 1);
        return TRUE;
    }
    lua_pop(L, ret + 1);
    /* propagate event further */
    return FALSE;
}

static void
menu_item_cb(GtkMenuItem *menuitem, widget_t *w)
{
    lua_State *L = globalconf.L;
    gpointer ref = g_object_get_data(G_OBJECT(menuitem), "lua_callback");
    luaH_object_push(L, w->ref);
    luaH_object_push(L, ref);
    luaH_dofunction(L, 1, 0);
}

static void
populate_popup_from_table(lua_State *L, GtkMenu *menu, widget_t *w)
{
    GtkWidget *item, *submenu;
    gpointer ref;
    const char *label;
    int i, len = lua_objlen(L, -1);

    /* walk table and build context menu */
    for(i = 1; i <= len; i++) {
        lua_rawgeti(L, -1, i);
        if((lua_type(L, -1) == LUA_TTABLE) && (lua_objlen(L, -1) >= 2)) {
            lua_rawgeti(L, -1, 1);
            label = lua_tostring(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, -1, 2);

            /* add new submenu */
            if(lua_type(L, -1) == LUA_TTABLE) {
                submenu = gtk_menu_new();
                item = gtk_menu_item_new_with_mnemonic(label);
                last_popup.items = g_slist_prepend(last_popup.items, item);
                last_popup.items = g_slist_prepend(last_popup.items, submenu);
                gtk_menu_item_set_submenu(GTK_MENU_ITEM(item), submenu);
                gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
                gtk_widget_show(item);
                populate_popup_from_table(L, GTK_MENU(submenu), w);
                lua_pop(L, 1);

            /* add context menu item */
            } else if(lua_type(L, -1) == LUA_TFUNCTION) {
                item = gtk_menu_item_new_with_mnemonic(label);
                last_popup.items = g_slist_prepend(last_popup.items, item);
                ref = luaH_object_ref(L, -1);
                last_popup.refs = g_slist_prepend(last_popup.refs, ref);
                g_object_set_data(G_OBJECT(item), "lua_callback", ref);
                gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
                gtk_widget_show(item);
                g_signal_connect(item, "activate", G_CALLBACK(menu_item_cb), (gpointer)w);
            }

        /* add separator if encounters `true` */
        } else if(lua_type(L, -1) == LUA_TBOOLEAN && luaH_checkboolean(L, -1)) {
            item = gtk_separator_menu_item_new();
            last_popup.items = g_slist_prepend(last_popup.items, item);
            gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
            gtk_widget_show(item);
        }
        lua_pop(L, 1);
    }
}

static void
populate_popup_cb(WebKitWebView *v, GtkMenu *menu, widget_t *w)
{
    (void) v;
    (void) menu;
    gint top;
    gint ret;

    GSList *iter;
    lua_State *L = globalconf.L;

    /* dereference context menu items callback functions from the last
       context menu */
    if (last_popup.refs) {
        for (iter = last_popup.refs; iter; iter = iter->next)
            luaH_object_unref(L, iter->data);
        g_slist_free(last_popup.refs);
        last_popup.refs = NULL;
    }

    /* destroy context menu item widgets from the last context menu */
    if (last_popup.items) {
        for (iter = last_popup.items; iter; iter = iter->next)
            gtk_widget_destroy(iter->data);
        g_slist_free(last_popup.items);
        last_popup.items = NULL;
    }

    luaH_object_push(L, w->ref);
    top = lua_gettop(L);
    ret = luaH_object_emit_signal(L, top, "populate-popup", 0, 1);
    if(ret && (lua_type(L, -1) == LUA_TTABLE))
        populate_popup_from_table(L, menu, w);
    lua_pop(L, ret + 1);
}

static void
webview_destructor(widget_t *w)
{
    g_ptr_array_remove(all_views, w);
    GtkWidget *view = g_object_get_data(G_OBJECT(w->widget), "webview");
    gtk_widget_destroy(GTK_WIDGET(view));
    gtk_widget_destroy(GTK_WIDGET(w->widget));
}

static void
init_soup(void)
{
    /* create soup session */
    Soup.session = webkit_get_default_session();

    /* load cookie jar */
    gchar *cookie_file = g_build_filename(globalconf.data_dir, "cookies.db", NULL);
    Soup.cookiejar = soup_cookie_jar_sqlite_new(cookie_file, FALSE);

    soup_session_add_feature(Soup.session, (SoupSessionFeature*) Soup.cookiejar);
    g_free(cookie_file);

    /* watch for property changes */
    g_signal_connect(G_OBJECT(Soup.session), "notify", G_CALLBACK(soup_notify_cb), NULL);
}

widget_t *
widget_webview(widget_t *w)
{
    w->index = luaH_webview_index;
    w->newindex = luaH_webview_newindex;
    w->destructor = webview_destructor;

    /* init properties hash table */
    if (!properties)
        webview_init_properties();

    /* keep a list of all webview widgets */
    if (!all_views)
        all_views = g_ptr_array_new();

    /* init soup session & cookies */
    if (!Soup.session)
        init_soup();

    GtkWidget *view = webkit_web_view_new();
    w->widget = gtk_scrolled_window_new(NULL, NULL);
    g_object_set_data(G_OBJECT(w->widget), "lua_widget", w);
    g_object_set_data(G_OBJECT(w->widget), "webview", view);
    gtk_container_add(GTK_CONTAINER(w->widget), view);

    /* set initial scrollbars state */
    show_scrollbars(w, TRUE);

    /* connect webview signals */
    g_object_connect(G_OBJECT(view),
      "signal::button-press-event",                   G_CALLBACK(webview_button_cb),            w,
      "signal::button-release-event",                 G_CALLBACK(webview_button_cb),            w,
      "signal::create-web-view",                      G_CALLBACK(create_web_view_cb),           w,
      "signal::download-requested",                   G_CALLBACK(download_request_cb),          w,
      "signal::expose-event",                         G_CALLBACK(expose_cb),                    w,
      "signal::focus-in-event",                       G_CALLBACK(focus_cb),                     w,
      "signal::focus-out-event",                      G_CALLBACK(focus_cb),                     w,
      "signal::hovering-over-link",                   G_CALLBACK(link_hover_cb),                w,
      "signal::key-press-event",                      G_CALLBACK(key_press_cb),                 w,
      "signal::mime-type-policy-decision-requested",  G_CALLBACK(mime_type_decision_cb),        w,
      "signal::navigation-policy-decision-requested", G_CALLBACK(navigation_decision_cb),       w,
      "signal::new-window-policy-decision-requested", G_CALLBACK(new_window_decision_cb),       w,
      "signal::notify",                               G_CALLBACK(notify_cb),                    w,
      "signal::notify::load-status",                  G_CALLBACK(notify_load_status_cb),        w,
      "signal::parent-set",                           G_CALLBACK(parent_set_cb),                w,
      "signal::populate-popup",                       G_CALLBACK(populate_popup_cb),            w,
      "signal::resource-request-starting",            G_CALLBACK(resource_request_starting_cb), w,
      NULL);

    /* show widgets */
    gtk_widget_show(view);
    gtk_widget_show(w->widget);

    g_ptr_array_add(all_views, w);

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
