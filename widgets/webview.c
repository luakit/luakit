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

#include <webkit/webkit.h>
#include <libsoup/soup-message.h>
#include <math.h>

#include "globalconf.h"
#include "widgets/common.h"
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

static struct {
    GSList *refs;
    GSList *items;
} last_popup = { NULL, NULL };

property_t webview_properties[] = {
  { L_TK_CUSTOM_ENCODING,   "custom-encoding",   CHAR,   TRUE  },
  { L_TK_EDITABLE,          "editable",          BOOL,   TRUE  },
  { L_TK_ENCODING,          "encoding",          CHAR,   FALSE },
  { L_TK_FULL_CONTENT_ZOOM, "full-content-zoom", BOOL,   TRUE  },
  { L_TK_ICON_URI,          "icon-uri",          CHAR,   FALSE },
  { L_TK_PROGRESS,          "progress",          DOUBLE, FALSE },
  { L_TK_TITLE,             "title",             CHAR,   FALSE },
  { L_TK_TRANSPARENT,       "transparent",       BOOL,   TRUE  },
  { L_TK_URI,               "uri",               CHAR,   FALSE }, /* dummy */
  { L_TK_ZOOM_LEVEL,        "zoom-level",        FLOAT,  TRUE  },
  { 0,                      NULL,                0,      0     },
};

property_t webview_settings_properties[] = {
  { L_TK_AUTO_LOAD_IMAGES,                          "auto-load-images",                          BOOL,  TRUE },
  { L_TK_AUTO_RESIZE_WINDOW,                        "auto-resize-window",                        BOOL,  TRUE },
  { L_TK_AUTO_SHRINK_IMAGES,                        "auto-shrink-images",                        BOOL,  TRUE },
  { L_TK_CURSIVE_FONT_FAMILY,                       "cursive-font-family",                       CHAR,  TRUE },
  { L_TK_DEFAULT_ENCODING,                          "default-encoding",                          CHAR,  TRUE },
  { L_TK_DEFAULT_FONT_FAMILY,                       "default-font-family",                       CHAR,  TRUE },
  { L_TK_DEFAULT_FONT_SIZE,                         "default-font-size",                         INT,   TRUE },
  { L_TK_DEFAULT_MONOSPACE_FONT_SIZE,               "default-monospace-font-size",               INT,   TRUE },
  { L_TK_ENABLE_CARET_BROWSING,                     "enable-caret-browsing",                     BOOL,  TRUE },
  { L_TK_ENABLE_DEFAULT_CONTEXT_MENU,               "enable-default-context-menu",               BOOL,  TRUE },
  { L_TK_ENABLE_DEVELOPER_EXTRAS,                   "enable-developer-extras",                   BOOL,  TRUE },
  { L_TK_ENABLE_DOM_PASTE,                          "enable-dom-paste",                          BOOL,  TRUE },
  { L_TK_ENABLE_FILE_ACCESS_FROM_FILE_URIS,         "enable-file-access-from-file-uris",         BOOL,  TRUE },
  { L_TK_ENABLE_HTML5_DATABASE,                     "enable-html5-database",                     BOOL,  TRUE },
  { L_TK_ENABLE_HTML5_LOCAL_STORAGE,                "enable-html5-local-storage",                BOOL,  TRUE },
  { L_TK_ENABLE_JAVA_APPLET,                        "enable-java-applet",                        BOOL,  TRUE },
  { L_TK_ENABLE_OFFLINE_WEB_APPLICATION_CACHE,      "enable-offline-web-application-cache",      BOOL,  TRUE },
  { L_TK_ENABLE_PAGE_CACHE,                         "enable-page-cache",                         BOOL,  TRUE },
  { L_TK_ENABLE_PLUGINS,                            "enable-plugins",                            BOOL,  TRUE },
  { L_TK_ENABLE_PRIVATE_BROWSING,                   "enable-private-browsing",                   BOOL,  TRUE },
  { L_TK_ENABLE_SCRIPTS,                            "enable-scripts",                            BOOL,  TRUE },
  { L_TK_ENABLE_SITE_SPECIFIC_QUIRKS,               "enable-site-specific-quirks",               BOOL,  TRUE },
  { L_TK_ENABLE_SPATIAL_NAVIGATION,                 "enable-spatial-navigation",                 BOOL,  TRUE },
  { L_TK_ENABLE_SPELL_CHECKING,                     "enable-spell-checking",                     BOOL,  TRUE },
  { L_TK_ENABLE_UNIVERSAL_ACCESS_FROM_FILE_URIS,    "enable-universal-access-from-file-uris",    BOOL,  TRUE },
  { L_TK_ENABLE_XSS_AUDITOR,                        "enable-xss-auditor",                        BOOL,  TRUE },
  { L_TK_ENFORCE_96_DPI,                            "enforce-96-dpi",                            BOOL,  TRUE },
  { L_TK_FANTASY_FONT_FAMILY,                       "fantasy-font-family",                       CHAR,  TRUE },
  { L_TK_JAVASCRIPT_CAN_ACCESS_CLIPBOARD,           "javascript-can-access-clipboard",           BOOL,  TRUE },
  { L_TK_JAVASCRIPT_CAN_OPEN_WINDOWS_AUTOMATICALLY, "javascript-can-open-windows-automatically", BOOL,  TRUE },
  { L_TK_MINIMUM_FONT_SIZE,                         "minimum-font-size",                         INT,   TRUE },
  { L_TK_MINIMUM_LOGICAL_FONT_SIZE,                 "minimum-logical-font-size",                 INT,   TRUE },
  { L_TK_MONOSPACE_FONT_FAMILY,                     "monospace-font-family",                     CHAR,  TRUE },
  { L_TK_PRINT_BACKGROUNDS,                         "print-backgrounds",                         BOOL,  TRUE },
  { L_TK_RESIZABLE_TEXT_AREAS,                      "resizable-text-areas",                      BOOL,  TRUE },
  { L_TK_SANS_SERIF_FONT_FAMILY,                    "sans-serif-font-family",                    CHAR,  TRUE },
  { L_TK_SERIF_FONT_FAMILY,                         "serif-font-family",                         CHAR,  TRUE },
  { L_TK_SPELL_CHECKING_LANGUAGES,                  "spell-checking-languages",                  CHAR,  TRUE },
  { L_TK_TAB_KEY_CYCLES_THROUGH_ELEMENTS,           "tab-key-cycles-through-elements",           BOOL,  TRUE },
  { L_TK_USER_AGENT,                                "user-agent",                                CHAR,  TRUE },
  { L_TK_USER_STYLESHEET_URI,                       "user-stylesheet-uri",                       CHAR,  TRUE },
  { L_TK_ZOOM_STEP,                                 "zoom-step",                                 FLOAT, TRUE },
  { 0,                                              NULL,                                        0,     0    },
};

static widget_t*
luaH_checkwebview(lua_State *L, gint udx)
{
    widget_t *w = luaH_checkwidget(L, udx);
    if (w->info->tok != L_TK_WEBVIEW)
        luaL_argerror(L, udx, "incorrect widget type (expected webview)");
    return w;
}

#include "widgets/webview/javascript.c"
#include "widgets/webview/frames.c"
#include "widgets/webview/downloads.c"
#include "widgets/webview/history.c"
#include "widgets/webview/scroll.c"

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

static void
notify_cb(WebKitWebView* UNUSED(v), GParamSpec *ps, widget_t *w)
{
    static GHashTable *wvprops = NULL;
    property_t *p;

    if (!wvprops) {
        wvprops = g_hash_table_new(g_str_hash, g_str_equal);
        for (p = webview_properties; p->name; p++)
            g_hash_table_insert(wvprops, (gpointer)p->name, (gpointer)p);
    }

    if ((p = g_hash_table_lookup(wvprops, ps->name))) {
        lua_State *L = globalconf.L;
        luaH_object_push(L, w->ref);
        luaH_object_property_signal(L, -1, p->tok);
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

static void
notify_load_status_cb(WebKitWebView *v, GParamSpec* UNUSED(ps), widget_t *w)
{
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
resource_request_starting_cb(WebKitWebView* UNUSED(v),
        WebKitWebFrame* UNUSED(f), WebKitWebResource* UNUSED(we),
        WebKitNetworkRequest *r, WebKitNetworkResponse* UNUSED(response),
        widget_t *w)
{
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
new_window_decision_cb(WebKitWebView* UNUSED(v), WebKitWebFrame* UNUSED(f),
        WebKitNetworkRequest *r, WebKitWebNavigationAction *na,
        WebKitWebPolicyDecision *pd, widget_t *w)
{
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
create_web_view_cb(WebKitWebView* UNUSED(v), WebKitWebFrame* UNUSED(f),
        widget_t *w)
{
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

static void
link_hover_cb(WebKitWebView* UNUSED(v), const gchar* UNUSED(t),
        const gchar *link, widget_t *w)
{
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
navigation_decision_cb(WebKitWebView* UNUSED(v), WebKitWebFrame* UNUSED(f),
        WebKitNetworkRequest *r, WebKitWebNavigationAction* UNUSED(a),
        WebKitWebPolicyDecision *p, widget_t *w)
{
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

static gint
luaH_webview_index(lua_State *L, luakit_token_t token)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    gint ret;

    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON

      /* push property methods */
      PF_CASE(CLEAR_SEARCH,         luaH_webview_clear_search)
      /* push search methods */
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

      /* push string properties */
      PS_CASE(HOVERED_URI,          d->hover)
      PS_CASE(URI,                  d->uri)

      /* push boolean properties */
      PB_CASE(VIEW_SOURCE, webkit_web_view_get_view_source_mode(d->view))

      case L_TK_FRAMES:
        return luaH_webview_push_frames(L, d);

      case L_TK_HISTORY:
        return luaH_webview_push_history(L, d->view);

      case L_TK_SCROLL:
        return luaH_webview_push_scroll_table(L);

      default:
        break;
    }

    if ((ret = luaH_gobject_index(L, webview_properties, token,
            G_OBJECT(d->view))))
        return ret;

    return luaH_gobject_index(L, webview_settings_properties, token,
            G_OBJECT(webkit_web_view_get_settings(d->view)));
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
    gchar *uri;

    switch(token)
    {
      case L_TK_URI:
        uri = parse_uri(luaL_checklstring(L, 3, &len));
        webkit_web_view_load_uri(d->view, uri);
        update_uri(d->widget, uri);
        g_free(uri);
        return 0;

      case L_TK_SHOW_SCROLLBARS:
        show_scrollbars(d, luaH_checkboolean(L, 3));
        return luaH_object_property_signal(L, 1, token);

      case L_TK_HISTORY:
        webview_set_history(L, d->view, 3);
        return luaH_object_property_signal(L, 1, token);

      case L_TK_VIEW_SOURCE:
        webkit_web_view_set_view_source_mode(d->view, luaH_checkboolean(L, 3));
        return luaH_object_property_signal(L, 1, token);

      default:
        break;
    }

    /* check for webview widget gobject properties */
    gboolean emit = luaH_gobject_newindex(L, webview_properties, token, 3,
            G_OBJECT(d->view));

    /* check for webkit widget's settings gobject properties */
    if (!emit)
        emit = luaH_gobject_newindex(L, webview_settings_properties, token, 3,
            G_OBJECT(webkit_web_view_get_settings(d->view)));

    return emit ? luaH_object_property_signal(L, 1, token) : 0;
}

static gboolean
expose_cb(GtkWidget* UNUSED(widget), GdkEventExpose* UNUSED(e), widget_t *w)
{
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
populate_popup_cb(WebKitWebView* UNUSED(v), GtkMenu *menu, widget_t *w)
{
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

static gboolean
scroll_event_cb(GtkWidget* UNUSED(v), GdkEventScroll *ev, widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_modifier_table_push(L, ev->state);
    lua_pushinteger(L, ((int)ev->direction) + 4);
    gint ret = luaH_object_emit_signal(L, -3, "button-release", 2, 1);
    gboolean catch = ret && lua_toboolean(L, -1) ? TRUE : FALSE;
    lua_pop(L, ret + 1);
    return catch;
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
widget_webview(widget_t *w, luakit_token_t UNUSED(token))
{
    w->index = luaH_webview_index;
    w->newindex = luaH_webview_newindex;
    w->destructor = webview_destructor;

    /* create private webview data struct */
    webview_data_t *d = g_slice_new0(webview_data_t);
    d->widget = w;
    w->data = d;

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
      "signal::document-load-finished",               G_CALLBACK(document_load_finished_cb),    w,
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
      "signal::scroll-event",                         G_CALLBACK(scroll_event_cb),              w,
      NULL);

    /* show widgets */
    gtk_widget_show(GTK_WIDGET(d->view));
    gtk_widget_show(GTK_WIDGET(d->win));

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
