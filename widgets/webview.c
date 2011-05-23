/*
 * widgets/webview.c - webkit webview widget
 *
 * Copyright © 2010-2011 Mason Larobina <mason.larobina@gmail.com>
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
#include <libsoup/soup-message.h>
#include <math.h>

#include "globalconf.h"
#include "widgets/common.h"
#include "clib/download.h"
#include "clib/soup/soup.h"
#include "common/property.h"
#include "luah.h"

typedef struct {
    /** The parent widget_t struct */
    widget_t *widget;
    /** The webview widget */
    WebKitWebView *view;
    /** The GtkScrolledWindow for the webview widget */
    GtkScrolledWindow *win;
    /** Current webview uri */
    gchar *uri;
    /** Currently hovered uri */
    gchar *hover;
    /** Scrollbar hide signal id */
    gulong hide_id;
} webview_data_t;

#define luaH_checkwvdata(L, udx) ((webview_data_t*)(luaH_checkwebview(L, udx)->data))

GHashTable *frames_by_view = NULL;

static struct {
    GSList *refs;
    GSList *items;
} last_popup = { NULL, NULL };

typedef struct {
    WebKitWebView *view;
    WebKitWebFrame *frame;
} frame_destroy_callback_t;

GHashTable *webview_properties = NULL;
property_t webview_properties_table[] = {
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
  { "javascript-can-access-clipboard",              BOOL,   SETTINGS,    TRUE,  NULL },
  { "javascript-can-open-windows-automatically",    BOOL,   SETTINGS,    TRUE,  NULL },
  { "minimum-font-size",                            INT,    SETTINGS,    TRUE,  NULL },
  { "minimum-logical-font-size",                    INT,    SETTINGS,    TRUE,  NULL },
  { "monospace-font-family",                        CHAR,   SETTINGS,    TRUE,  NULL },
  { "print-backgrounds",                            BOOL,   SETTINGS,    TRUE,  NULL },
  { "progress",                                     DOUBLE, WEBKITVIEW,  FALSE, NULL },
  { "resizable-text-areas",                         BOOL,   SETTINGS,    TRUE,  NULL },
  { "sans-serif-font-family",                       CHAR,   SETTINGS,    TRUE,  NULL },
  { "serif-font-family",                            CHAR,   SETTINGS,    TRUE,  NULL },
  { "spell-checking-languages",                     CHAR,   SETTINGS,    TRUE,  NULL },
  { "tab-key-cycles-through-elements",              BOOL,   SETTINGS,    TRUE,  NULL },
  { "title",                                        CHAR,   WEBKITVIEW,  FALSE, NULL },
  { "transparent",                                  BOOL,   WEBKITVIEW,  TRUE,  NULL },
  { "user-agent",                                   CHAR,   SETTINGS,    TRUE,  NULL },
  { "user-stylesheet-uri",                          CHAR,   SETTINGS,    TRUE,  NULL },
  { "zoom-level",                                   FLOAT,  WEBKITVIEW,  TRUE,  NULL },
  { "zoom-step",                                    FLOAT,  SETTINGS,    TRUE,  NULL },
  { NULL,                                           0,      0,           0,     NULL },
};

widget_t*
luaH_checkwebview(lua_State *L, gint udx)
{
    widget_t *w = luaH_checkwidget(L, udx);
    if (w->info->tok != L_TK_WEBVIEW)
        luaL_argerror(L, udx, "incorrect widget type (expected webview)");
    return w;
}

static JSValueRef
webview_registered_function_callback(JSContextRef context, JSObjectRef fun,
        JSObjectRef thisObject, size_t argumentCount,
        const JSValueRef *arguments, JSValueRef *exception)
{
    (void) thisObject;
    (void) argumentCount;
    (void) arguments;

    lua_State *L = globalconf.L;
    gpointer ref = JSObjectGetPrivate(fun);
    // get function
    luaH_object_push(L, ref);
    // call function
    gint ret = lua_pcall(L, 0, 0, 0);
    // handle errors
    if (ret != 0) {
        const gchar *exn_cstring = luaL_checkstring(L, -1);
        lua_pop(L, 1);
        JSStringRef exn_js_string = JSStringCreateWithUTF8CString(exn_cstring);
        JSValueRef exn_js_value = JSValueMakeString(context, exn_js_string);
        *exception = JSValueToObject(context, exn_js_value, NULL);
        JSStringRelease(exn_js_string);
    }
    return JSValueMakeUndefined(context);
}

static void
webview_collect_registered_function(JSObjectRef obj)
{
    lua_State *L = globalconf.L;
    gpointer ref = JSObjectGetPrivate(obj);
    luaH_object_unref(L, ref);
}

static void
webview_register_function(WebKitWebFrame *frame, const gchar *name, gpointer ref)
{
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
webview_eval_js(WebKitWebFrame *frame, const gchar *script, const gchar *file)
{
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
            gchar js_result_utf8[js_result_size];
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
            gchar cstr[size];
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
            gchar cstr[size];
            JSStringGetUTF8CString(val, cstr, size);
            g_printf(":%s: ", cstr);
        }
        JSStringRelease(prop);
        JSStringRelease(val);

        /* Print message */
        val = JSValueToStringCopy(context, exc, NULL);
        size = JSStringGetMaximumUTF8CStringSize(val);
        if(size) {
            gchar cstr[size];
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
luaH_webview_get_property(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    return luaH_get_property(L, webview_properties, d->view, 2);
}

static gint
luaH_webview_set_property(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    return luaH_set_property(L, webview_properties, d->view, 2, 3);
}

static gint
luaH_webview_load_string(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    const gchar *string = luaL_checkstring(L, 2);
    const gchar *base_uri = luaL_checkstring(L, 3);
    WebKitWebFrame *frame = webkit_web_view_get_main_frame(d->view);
    webkit_web_frame_load_alternate_string(frame, string, base_uri, base_uri);
    return 0;
}

static gint
luaH_webview_register_function(lua_State *L)
{
    WebKitWebFrame *frame = NULL;
    webview_data_t *d = luaH_checkwvdata(L, 1);
    const gchar *name = luaL_checkstring(L, 2);

    /* get lua callback function */
    luaH_checkfunction(L, 3);
    lua_pushvalue(L, 3);
    gpointer ref = luaH_object_ref(L, -1);

    /* Check if function should be registered on currently focused frame */
    if (lua_gettop(L) >= 4 && luaH_checkboolean(L, 4))
        frame = webkit_web_view_get_focused_frame(d->view);

    /* Fall back on main frame */
    if (!frame)
        frame = webkit_web_view_get_main_frame(d->view);

    /* register function */
    webview_register_function(frame, name, ref);
    return 0;
}

static gint
luaH_webview_eval_js(lua_State *L)
{
    WebKitWebFrame *frame = NULL;
    webview_data_t *d = luaH_checkwvdata(L, 1);
    const gchar *script = luaL_checkstring(L, 2);
    const gchar *filename = luaL_checkstring(L, 3);

    /* Check if js should be run on currently focused frame */
    if (lua_gettop(L) >= 4) {
        if (lua_islightuserdata(L, 4))
            frame = lua_touserdata(L, 4);
        else if (lua_toboolean(L, 4))
            frame = webkit_web_view_get_focused_frame(d->view);
    }

    /* Fall back on main frame */
    if (!frame)
        frame = webkit_web_view_get_main_frame(d->view);

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
    if ((p = g_hash_table_lookup(webview_properties, ps->name))) {
        lua_State *L = globalconf.L;
        luaH_object_push(L, w->ref);
        luaH_object_emit_signal(L, -1, p->signame, 0, 0);
        lua_pop(L, 1);
    }
}

static void
update_uri(widget_t *w, const gchar *uri)
{
    webview_data_t *d = w->data;

    if (!uri) {
        uri = webkit_web_view_get_uri(d->view);
        if (!uri || !uri[0])
            uri = "about:blank";
    }

    /* uris are the same, do nothing */
    if (g_strcmp0(d->uri, uri)) {
        g_free(d->uri);
        d->uri = g_strdup(uri);
        lua_State *L = globalconf.L;
        luaH_object_push(L, w->ref);
        luaH_object_emit_signal(L, -1, "property::uri", 0, 0);
        lua_pop(L, 1);
    }
}

static gint
luaH_webview_push_frames(lua_State *L, webview_data_t *d)
{
    GHashTable *frames = g_hash_table_lookup(frames_by_view, d->view);
    lua_createtable(L, g_hash_table_size(frames), 0);
    gint i = 1, tidx = lua_gettop(L);
    gpointer frame;
    GHashTableIter iter;
    g_hash_table_iter_init(&iter, frames);
    while (g_hash_table_iter_next(&iter, &frame, NULL)) {
        lua_pushlightuserdata(L, frame);
        lua_rawseti(L, tidx, i++);
    }
    return 1;
}

static void
notify_load_status_cb(WebKitWebView *v, GParamSpec *ps, widget_t *w)
{
    (void) ps;

    /* Get load status */
    WebKitLoadStatus s = webkit_web_view_get_load_status(v);

    /* get load status literal */
    gchar *name = NULL;
    switch (s) {

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

    /* update uri after redirects & etc */
    if (s == WEBKIT_LOAD_COMMITTED || s == WEBKIT_LOAD_FINISHED)
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

    luaH_object_push(L, w->ref);
    lua_pushstring(L, uri);
    lua_pushstring(L, mime);
    gint ret = luaH_object_emit_signal(L, -3, "mime-type-decision", 2, 1);

    if (ret && !lua_toboolean(L, -1))
        /* User responded with false, ignore request */
        webkit_web_policy_decision_ignore(pd);
    else if (!webkit_web_view_can_show_mime_type(v, mime))
        webkit_web_policy_decision_download(pd);
    else
        webkit_web_policy_decision_use(pd);

    lua_pop(L, ret + 1);
    return TRUE;
}

static void
frame_destroyed_cb(frame_destroy_callback_t *st)
{
    gpointer hash = g_hash_table_lookup(frames_by_view, st->view);
    /* the view might be destroyed before the frames */
    if (hash)
        g_hash_table_remove(hash, st->frame);
    g_slice_free(frame_destroy_callback_t, st);
}

static void
document_load_finished_cb(WebKitWebView *v, WebKitWebFrame *f, widget_t *w)
{
    (void) w;
    /* add a bogus property to the frame so we get notified when it's destroyed */
    frame_destroy_callback_t *st = g_slice_new(frame_destroy_callback_t);
    st->view = v;
    st->frame = f;
    g_object_set_data_full(G_OBJECT(f), "dummy-destroy-notify", st,
            (GDestroyNotify)frame_destroyed_cb);
    GHashTable *frames = g_hash_table_lookup(frames_by_view, v);
    g_hash_table_insert(frames, f, NULL);
}

static gboolean
resource_request_starting_cb(WebKitWebView *v, WebKitWebFrame *f,
        WebKitWebResource *we, WebKitNetworkRequest *r,
        WebKitNetworkResponse *response, widget_t *w)
{
    (void) v;
    (void) f;
    (void) we;
    (void) f;
    (void) response;
    const gchar *uri = webkit_network_request_get_uri(r);
    lua_State *L = globalconf.L;

    luaH_object_push(L, w->ref);
    lua_pushstring(L, uri);
    gint ret = luaH_object_emit_signal(L, -2, "resource-request-starting", 1, 1);

    if (ret && !lua_toboolean(L, -1))
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
    if (ret && lua_toboolean(L, -1)) {
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
    WebKitWebView *view = NULL;
    widget_t *new;

    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    gint top = lua_gettop(L);
    gint ret = luaH_object_emit_signal(L, top, "create-web-view", 0, 1);

    /* check for new webview widget */
    if (ret) {
        if ((new = luaH_towidget(L, top + 1))) {
            if (new->info->tok == L_TK_WEBVIEW)
                view = WEBKIT_WEB_VIEW(((webview_data_t*)new->data)->view);
            else
                warn("invalid return widget type (expected webview, got %s)",
                        new->info->name);
        } else
            warn("invalid signal return object type (expected webview widget, "
                    "got %s)", lua_typename(L, lua_type(L, top + 1)));
    }

    lua_settop(L, top);
    return view;
}

static gboolean
download_request_cb(WebKitWebView *v, WebKitDownload *dl, widget_t *w)
{
    (void) v;
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_download_push(L, dl);
    gint ret = luaH_object_emit_signal(L, 1, "download-request", 1, 1);
    gboolean handled = (ret && lua_toboolean(L, 2));
    lua_pop(L, 1 + ret);
    return handled;
}

static void
link_hover_cb(WebKitWebView *v, const gchar *t, const gchar *link, widget_t *w)
{
    (void) t;
    (void) v;
    lua_State *L = globalconf.L;
    webview_data_t *d = w->data;

    /* links are identical, do nothing */
    if (d->hover && !g_strcmp0(d->hover, link))
        return;

    luaH_object_push(L, w->ref);

    if (d->hover) {
        lua_pushstring(L, d->hover);
        g_free(d->hover);
        luaH_object_emit_signal(L, -2, "link-unhover", 1, 0);
    }

    if (link) {
        d->hover = g_strdup(link);
        lua_pushstring(L, d->hover);
        luaH_object_emit_signal(L, -2, "link-hover", 1, 0);
    } else
        d->hover = NULL;

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
    gint top = lua_gettop(L);
    const gchar *uri = webkit_network_request_get_uri(r);

    luaH_object_push(L, w->ref);
    lua_pushstring(L, uri);
    gint ret = luaH_object_emit_signal(L, -2, "navigation-request", 1, 1);

    if (ret && !lua_toboolean(L, -1))
        /* User responded with false, do not continue navigation request */
        webkit_web_policy_decision_ignore(p);
    else
        webkit_web_policy_decision_use(p);

    lua_settop(L, top);
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
    webview_data_t *d = luaH_checkwvdata(L, 1);
    GtkAdjustment *a = gtk_scrolled_window_get_vadjustment(d->win);
    return luaH_adjustment_push_values(L, a);
}

static gint
luaH_webview_get_scroll_horiz(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    GtkAdjustment *a = gtk_scrolled_window_get_hadjustment(d->win);
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
    webview_data_t *d = luaH_checkwvdata(L, 1);
    gdouble value = (gdouble) luaL_checknumber(L, 2);
    GtkAdjustment *a = gtk_scrolled_window_get_vadjustment(d->win);
    adjustment_set(a, value);
    return 0;
}

static gint
luaH_webview_set_scroll_horiz(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    gdouble value = (gdouble) luaL_checknumber(L, 2);
    GtkAdjustment *a = gtk_scrolled_window_get_hadjustment(d->win);
    adjustment_set(a, value);
    return 0;
}

static gint
luaH_webview_go_back(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    gint steps = (gint) luaL_checknumber(L, 2);
    webkit_web_view_go_back_or_forward(d->view, steps * -1);
    return 0;
}

static gint
luaH_webview_go_forward(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    gint steps = (gint) luaL_checknumber(L, 2);
    webkit_web_view_go_back_or_forward(d->view, steps);
    return 0;
}

static gint
luaH_webview_get_view_source(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    lua_pushboolean(L, webkit_web_view_get_view_source_mode(d->view));
    return 1;
}

static gint
luaH_webview_set_view_source(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    gboolean show = luaH_checkboolean(L, 2);
    webkit_web_view_set_view_source_mode(d->view, show);
    webkit_web_view_reload(d->view);
    return 0;
}

static gint
luaH_webview_reload(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    webkit_web_view_reload(d->view);
    return 0;
}

static gint
luaH_webview_reload_bypass_cache(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    webkit_web_view_reload_bypass_cache(d->view);
    return 0;
}

static gint
luaH_webview_search(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    const gchar *text = luaL_checkstring(L, 2);
    gboolean case_sensitive = luaH_checkboolean(L, 3);
    gboolean forward = luaH_checkboolean(L, 4);
    gboolean wrap = luaH_checkboolean(L, 5);

    webkit_web_view_unmark_text_matches(d->view);
    gboolean ret = webkit_web_view_search_text(d->view, text, case_sensitive,
            forward, wrap);
    if (ret) {
        webkit_web_view_mark_text_matches(d->view, text, case_sensitive, 0);
        webkit_web_view_set_highlight_text_matches(d->view, TRUE);
    }
    lua_pushboolean(L, ret);
    return 1;
}

static gint
luaH_webview_clear_search(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    webkit_web_view_unmark_text_matches(d->view);
    return 0;
}

static gint
luaH_webview_loading(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    WebKitLoadStatus s = webkit_web_view_get_load_status(d->view);
    lua_pushboolean(L, (s == WEBKIT_LOAD_FIRST_VISUALLY_NON_EMPTY_LAYOUT ||
            s == WEBKIT_LOAD_PROVISIONAL ||
            s == WEBKIT_LOAD_COMMITTED) ? TRUE : FALSE);
    return 1;
}

static gint
luaH_webview_stop(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    webkit_web_view_stop_loading(d->view);
    return 0;
}

/* check for trusted ssl certificate */
static gint
luaH_webview_ssl_trusted(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    const gchar *uri = webkit_web_view_get_uri(d->view);
    if (uri && !strncmp(uri, "https", 5)) {
        WebKitWebFrame *frame = webkit_web_view_get_main_frame(d->view);
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
show_scrollbars(webview_data_t *d, gboolean show)
{
    GObject *frame = G_OBJECT(webkit_web_view_get_main_frame(d->view));

    /* show scrollbars */
    if (show) {
        if (d->hide_id)
            g_signal_handler_disconnect(frame, d->hide_id);
        gtk_scrolled_window_set_policy(d->win,
                GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
        d->hide_id = 0;

    /* hide scrollbars */
    } else if (!d->hide_id) {
        gtk_scrolled_window_set_policy(d->win,
                GTK_POLICY_NEVER, GTK_POLICY_NEVER);
        d->hide_id = g_signal_connect(frame, "scrollbars-policy-changed",
                G_CALLBACK(true_cb), NULL);
    }
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
luaH_webview_can_go_back(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    lua_pushboolean(L, webkit_web_view_can_go_back(d->view));
    return 1;
}

static gint
luaH_webview_can_go_forward(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    lua_pushboolean(L, webkit_web_view_can_go_forward(d->view));
    return 1;
}

static gint
luaH_webview_index(lua_State *L, luakit_token_t token)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);

    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON

      /* push property methods */
      PF_CASE(GET_PROPERTY,         luaH_webview_get_property)
      PF_CASE(SET_PROPERTY,         luaH_webview_set_property)
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
      PF_CASE(CAN_GO_BACK,          luaH_webview_can_go_back)
      PF_CASE(CAN_GO_FORWARD,       luaH_webview_can_go_forward)
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
      PS_CASE(HOVERED_URI,          d->hover)
      PS_CASE(URI,                  d->uri)

      case L_TK_FRAMES:
        return luaH_webview_push_frames(L, d);

      case L_TK_HISTORY:
        return luaH_webview_push_history(L, d->view);

      default:
        break;
    }

    return 0;
}

static gchar*
parse_uri(const gchar *uri) {
    /* check for null uri */
    if (!uri || !uri[0] || !g_strcmp0(uri, "about:blank"))
        return g_strdup("about:blank");
    /* check for scheme or "about:blank" */
    else if (g_strrstr(uri, "://"))
        return g_strdup(uri);
    /* check if uri points to a file */
    else if (file_exists(uri)) {
        if (g_path_is_absolute(uri))
            return g_strdup_printf("file://%s", uri);
        else { /* make path absolute */
            gchar *cwd = g_get_current_dir();
            gchar *path = g_build_filename(cwd, uri, NULL);
            gchar *new = g_strdup_printf("file://%s", path);
            g_free(cwd);
            g_free(path);
            return new;
        }
    }
    /* default to http:// scheme */
    return g_strdup_printf("http://%s", uri);
}

/* The __newindex method for the webview object */
static gint
luaH_webview_newindex(lua_State *L, luakit_token_t token)
{
    size_t len;
    webview_data_t *d = luaH_checkwvdata(L, 1);
    property_tmp_value_t tmp;

    switch(token)
    {
      case L_TK_URI:
        tmp.c = parse_uri(luaL_checklstring(L, 3, &len));
        webkit_web_view_load_uri(d->view, tmp.c);
        update_uri(d->widget, tmp.c);
        g_free(tmp.c);
        return 0;

      case L_TK_SHOW_SCROLLBARS:
        show_scrollbars(d, luaH_checkboolean(L, 3));
        break;

      case L_TK_HISTORY:
        webview_set_history(L, d->view, 3);
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
    if (ret && lua_toboolean(L, -1)) {
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
hide_popup_cb() {
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
}

static void
populate_popup_from_table(lua_State *L, GtkMenu *menu, widget_t *w)
{
    GtkWidget *item, *submenu;
    gpointer ref;
    const gchar *label;
    gint i, len = lua_objlen(L, -1);

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
        } else if(lua_type(L, -1) == LUA_TBOOLEAN && lua_toboolean(L, -1)) {
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
    lua_State *L = globalconf.L;
    gint top = lua_gettop(L);
    luaH_object_push(L, w->ref);
    gint ret = luaH_object_emit_signal(L, top + 1, "populate-popup", 0, 1);
    if (ret && lua_istable(L, -1))
        populate_popup_from_table(L, menu, w);
    lua_settop(L, top);

    /* destroy all context menu items when we are finished with them */
#if WEBKIT_CHECK_VERSION(1, 4, 0)
    g_signal_connect(menu, "unrealize", G_CALLBACK(hide_popup_cb), NULL);
#else
    g_signal_connect(menu, "hide", G_CALLBACK(hide_popup_cb), NULL);
#endif
}

static void
webview_destructor(widget_t *w)
{
    webview_data_t *d = w->data;
    g_ptr_array_remove(globalconf.webviews, w);
    gtk_widget_destroy(GTK_WIDGET(d->view));
    gtk_widget_destroy(GTK_WIDGET(d->win));
    g_hash_table_remove(frames_by_view, d->view);
    g_free(d->uri);
    g_free(d->hover);
    g_slice_free(webview_data_t, d);
}

widget_t *
widget_webview(widget_t *w)
{
    w->index = luaH_webview_index;
    w->newindex = luaH_webview_newindex;
    w->destructor = webview_destructor;

    /* create private webview data struct */
    w->data = g_slice_new0(webview_data_t);
    webview_data_t *d = (webview_data_t*)w->data;
    d->widget = w;

    /* init properties hash table */
    if (!webview_properties)
        webview_properties = hash_properties(webview_properties_table);

    /* keep a list of all webview widgets */
    if (!globalconf.webviews)
        globalconf.webviews = g_ptr_array_new();

    if (!frames_by_view)
        frames_by_view = g_hash_table_new_full(g_direct_hash, g_direct_equal,
                NULL, (GDestroyNotify) g_hash_table_destroy);

    /* create widgets */
    d->view = WEBKIT_WEB_VIEW(webkit_web_view_new());
    d->win = GTK_SCROLLED_WINDOW(gtk_scrolled_window_new(NULL, NULL));
    w->widget = GTK_WIDGET(d->win);

    /* set gobject property to give other widgets a pointer to our webview */
    g_object_set_data(G_OBJECT(w->widget), "lua_widget", w);

    /* add webview to scrolled window */
    gtk_container_add(GTK_CONTAINER(d->win), GTK_WIDGET(d->view));

    /* set initial scrollbars state */
    show_scrollbars(d, TRUE);

    /* insert data into global tables and arrays */
    g_ptr_array_add(globalconf.webviews, w);

    g_hash_table_insert(frames_by_view, d->view,
            g_hash_table_new(g_direct_hash, g_direct_equal));

    /* connect webview signals */
    g_object_connect(G_OBJECT(d->view),
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
      "signal::document-load-finished",               G_CALLBACK(document_load_finished_cb),    w,
      NULL);

    /* show widgets */
    gtk_widget_show(GTK_WIDGET(d->view));
    gtk_widget_show(GTK_WIDGET(d->win));

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
