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

#include <webkit2/webkit2.h>
#include <math.h>

#include "globalconf.h"
#include "widgets/common.h"
#include "common/property.h"
#include "luah.h"
#include "clib/widget.h"

typedef struct _webview_scroll_anim_t {
    /** Smooth scroll offset at animation start */
    gdouble source;
    /** Smooth scroll offset at animation end */
    gdouble target;
    /** Time at which animation began */
    guint64 start_time;
} webview_scroll_anim_t;

typedef struct {
    /** The parent widget_t struct */
    widget_t *widget;
    /** The webview widget */
    WebKitWebView *view;
    /** The user content manager for the webview */
    WebKitUserContentManager *user_content;
    /** A list of stylesheets enabled for this user content */
    GList *stylesheets;
    /** Helpers for user content manager updating */
    gboolean stylesheet_added,
             stylesheet_removed,
             stylesheet_refreshed;
    /** Current webview uri */
    gchar *uri;
    /** Currently hovered uri */
    gchar *hover;
    /** Scrollbar hide signal id */
    gulong hide_id;

    /** Inspector properties */
    WebKitWebInspector *inspector;
    /** Whether inspector is open */
    gboolean inspector_open;

    guint htr_context;
    gboolean is_committed;
    gboolean is_failed;

    /** Animation state for horizontal scrolling */
    webview_scroll_anim_t hscroll;
    /** Animation state for vertical scrolling */
    webview_scroll_anim_t vscroll;
    /** Scroll animation duration */
    guint scroll_time_msec;
    /** Whether a smooth scroll is currently occurring */
    gboolean smooth_scroll;
    /** Per-frame callback for smooth scrolling */
    guint scroll_cb_id;

    /** Document size */
    gint doc_w, doc_h;
    /** Viewport size */
    gint win_w, win_h;
    /** Current scroll position */
    gint scroll_x, scroll_y;
} webview_data_t;

#define luaH_checkwvdata(L, udx) ((webview_data_t*)(luaH_checkwebview(L, udx)->data))

static struct {
    GSList *refs;
    GSList *old_refs;
} last_popup = { NULL, NULL };

property_t webview_properties[] = {
  { L_TK_PROGRESS,    "estimated-load-progress", DOUBLE, FALSE },
  { L_TK_IS_LOADING,        "is-loading",        BOOL,   FALSE },
  { L_TK_TITLE,             "title",             CHAR,   FALSE },
  { L_TK_URI,               "uri",               CHAR,   FALSE }, /* dummy */
  { L_TK_ZOOM_LEVEL,        "zoom-level",        DOUBLE,  TRUE },
  { 0,                      NULL,                0,      0     },
};

property_t webview_settings_properties[] = {
  { L_TK_ALLOW_MODAL_DIALOGS,                       "allow-modal-dialogs",                       BOOL,  TRUE },
  { L_TK_AUTO_LOAD_IMAGES,                          "auto-load-images",                          BOOL,  TRUE },
  { L_TK_CURSIVE_FONT_FAMILY,                       "cursive-font-family",                       CHAR,  TRUE },
  { L_TK_DEFAULT_CHARSET,                           "default-charset",                           CHAR,  TRUE },
  { L_TK_DEFAULT_FONT_FAMILY,                       "default-font-family",                       CHAR,  TRUE },
  { L_TK_DEFAULT_FONT_SIZE,                         "default-font-size",                         INT,   TRUE },
  { L_TK_DEFAULT_MONOSPACE_FONT_SIZE,               "default-monospace-font-size",               INT,   TRUE },
  { L_TK_DRAW_COMPOSITING_INDICATORS,               "draw-compositing-indicators",               BOOL,  TRUE },
  { L_TK_ENABLE_ACCELERATED_2D_CANVAS,              "enable-accelerated-2d-canvas",              BOOL,  TRUE },
  { L_TK_ENABLE_CARET_BROWSING,                     "enable-caret-browsing",                     BOOL,  TRUE },
  { L_TK_ENABLE_DEVELOPER_EXTRAS,                   "enable-developer-extras",                   BOOL,  TRUE },
  { L_TK_ENABLE_DNS_PREFETCHING,                    "enable-dns-prefetching",                    BOOL,  TRUE },
  { L_TK_ENABLE_FRAME_FLATTENING,                   "enable-frame-flattening",                   BOOL,  TRUE },
  { L_TK_ENABLE_FULLSCREEN,                         "enable-fullscreen",                         BOOL,  TRUE },
  { L_TK_ENABLE_HTML5_DATABASE,                     "enable-html5-database",                     BOOL,  TRUE },
  { L_TK_ENABLE_HTML5_LOCAL_STORAGE,                "enable-html5-local-storage",                BOOL,  TRUE },
  { L_TK_ENABLE_HYPERLINK_AUDITING,                 "enable-hyperlink-auditing",                 BOOL,  TRUE },
  { L_TK_ENABLE_JAVA,                               "enable-java",                               BOOL,  TRUE },
  { L_TK_ENABLE_JAVASCRIPT,                         "enable-javascript",                         BOOL,  TRUE },
  { L_TK_ENABLE_MEDIA_STREAM,                       "enable-media-stream",                       BOOL,  TRUE },
  { L_TK_ENABLE_MEDIASOURCE,                        "enable-mediasource",                        BOOL,  TRUE },
  { L_TK_ENABLE_OFFLINE_WEB_APPLICATION_CACHE,      "enable-offline-web-application-cache",      BOOL,  TRUE },
  { L_TK_ENABLE_PAGE_CACHE,                         "enable-page-cache",                         BOOL,  TRUE },
  { L_TK_ENABLE_PLUGINS,                            "enable-plugins",                            BOOL,  TRUE },
  { L_TK_ENABLE_PRIVATE_BROWSING,                   "enable-private-browsing",                   BOOL,  TRUE },
  /* replaces resizable-text-areas */
  { L_TK_ENABLE_RESIZABLE_TEXT_AREAS,               "enable-resizable-text-areas",               BOOL,  TRUE },
  { L_TK_ENABLE_SITE_SPECIFIC_QUIRKS,               "enable-site-specific-quirks",               BOOL,  TRUE },
  { L_TK_ENABLE_SMOOTH_SCROLLING,                   "enable-smooth-scrolling",                   BOOL,  TRUE },
  { L_TK_ENABLE_SPATIAL_NAVIGATION,                 "enable-spatial-navigation",                 BOOL,  TRUE },
  { L_TK_ENABLE_WEBGL,                              "enable-webgl",                              BOOL,  TRUE },
  { L_TK_ENABLE_TABS_TO_LINKS,                      "enable-tabs-to-links",                      BOOL,  TRUE },
  { L_TK_ENABLE_WEBAUDIO,                           "enable-webaudio",                           BOOL,  TRUE },
  { L_TK_ENABLE_WRITE_CONSOLE_MESSAGES_TO_STDOUT,   "enable-write-console-messages-to-stdout",   BOOL,  TRUE },
  { L_TK_ENABLE_XSS_AUDITOR,                        "enable-xss-auditor",                        BOOL,  TRUE },
  { L_TK_FANTASY_FONT_FAMILY,                       "fantasy-font-family",                       CHAR,  TRUE },
  { L_TK_JAVASCRIPT_CAN_ACCESS_CLIPBOARD,           "javascript-can-access-clipboard",           BOOL,  TRUE },
  { L_TK_JAVASCRIPT_CAN_OPEN_WINDOWS_AUTOMATICALLY, "javascript-can-open-windows-automatically", BOOL,  TRUE },
  { L_TK_LOAD_ICONS_IGNORING_IMAGE_LOAD_SETTING,    "load-icons-ignoring-image-load-setting",    BOOL,  TRUE },
  { L_TK_MEDIA_PLAYBACK_ALLOWS_INLINE,              "media-playback-allows-inline",              BOOL,  TRUE },
  { L_TK_MEDIA_PLAYBACK_REQUIRES_GESTURE,           "media-playback-requires-user-gesture",      BOOL,  TRUE },
  { L_TK_MINIMUM_FONT_SIZE,                         "minimum-font-size",                         INT,   TRUE },
  { L_TK_MONOSPACE_FONT_FAMILY,                     "monospace-font-family",                     CHAR,  TRUE },
  { L_TK_PICTOGRAPH_FONT_FAMILY,                    "pictograph-font-family",                    CHAR,  TRUE },
  { L_TK_PRINT_BACKGROUNDS,                         "print-backgrounds",                         BOOL,  TRUE },
  { L_TK_SANS_SERIF_FONT_FAMILY,                    "sans-serif-font-family",                    CHAR,  TRUE },
  { L_TK_SERIF_FONT_FAMILY,                         "serif-font-family",                         CHAR,  TRUE },
  { L_TK_USER_AGENT,                                "user-agent",                                CHAR,  TRUE },
  { L_TK_ZOOM_TEXT_ONLY,                            "zoom-text-only",                            BOOL,  TRUE },
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

static void update_uri(widget_t *w, const gchar *uri);

#include "widgets/webview/javascript.c"
#include "widgets/webview/downloads.c"
#include "widgets/webview/history.c"
#include "widgets/webview/scroll.c"
#include "widgets/webview/inspector.c"
#include "widgets/webview/find_controller.c"
#include "widgets/webview/stylesheets.c"
#include "widgets/webview/auth.c"

static gint
luaH_webview_load_string(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    const gchar *string = luaL_checkstring(L, 2);
    const gchar *base_uri = luaL_checkstring(L, 3);
    webkit_web_view_load_alternate_html(d->view, string, base_uri, NULL);
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

static gboolean
load_failed_cb(WebKitWebView* UNUSED(v), WebKitLoadEvent UNUSED(e),
        gchar *failing_uri, gpointer error, widget_t *w)
{
    lua_State *L = globalconf.L;
    ((webview_data_t*) w->data)->is_failed = TRUE;
    luaH_object_push(L, w->ref);
    lua_pushstring(L, "failed");
    lua_pushstring(L, failing_uri);
    lua_pushstring(L, ((GError*) error)->message);
    gint ret = luaH_object_emit_signal(L, -4, "load-status", 3, 1);
    gboolean ignore = ret && lua_toboolean(L, -1);
    lua_pop(L, ret + 1);
    return ignore;
}

static int
luaH_webview_push_certificate_flags(lua_State *L, GTlsCertificateFlags errors)
{
    lua_newtable(L);
    int n = 1;

#define CASE(err, str) \
    if (errors & G_TLS_CERTIFICATE_##err) { \
        lua_pushliteral(L, str); \
        lua_rawseti(L, -2, n++); \
    }

    CASE(UNKNOWN_CA, "unknown-ca")
    CASE(BAD_IDENTITY, "bad-identity")
    CASE(NOT_ACTIVATED, "not-activated")
    CASE(EXPIRED, "expired")
    CASE(REVOKED, "revoked")
    CASE(INSECURE, "insecure")
    CASE(GENERIC_ERROR, "generic-error")

    return 1;
}

static gboolean
load_failed_tls_cb(WebKitWebView* UNUSED(v), gchar *failing_uri,
        GTlsCertificate *UNUSED(certificate), GTlsCertificateFlags errors, widget_t *w)
{
    lua_State *L = globalconf.L;
    ((webview_data_t*) w->data)->is_failed = TRUE;
    luaH_object_push(L, w->ref);
    lua_pushliteral(L, "failed");
    lua_pushstring(L, failing_uri);
    lua_pushliteral(L, "Unacceptable TLS certificate");
    luaH_webview_push_certificate_flags(L, errors);
    luaH_object_emit_signal(L, -5, "load-status", 4, 0);
    lua_pop(L, 1);
    return TRUE; /* Prevent load-failed signal */
}

static void
load_changed_cb(WebKitWebView* UNUSED(v), WebKitLoadEvent e, widget_t *w)
{
    /* get load status literal */
    gchar *name = NULL;
    switch (e) {

#define LT_CASE(a, l) case WEBKIT_LOAD_##a: name = l; break;
        LT_CASE(STARTED,                         "provisional")
        LT_CASE(REDIRECTED,                      "redirected")
        LT_CASE(COMMITTED,                       "committed")
        LT_CASE(FINISHED,                        "finished")
#undef  LT_CASE

      default:
        warn("programmer error, unable to get load status literal");
        break;
    }

    /* update uri after redirects & etc */
    if (e == WEBKIT_LOAD_COMMITTED || e == WEBKIT_LOAD_FINISHED) {
        ((webview_data_t*) w->data)->is_committed = TRUE;
        update_uri(w, NULL);
    }

    lua_State *L = globalconf.L;

    if (e == WEBKIT_LOAD_COMMITTED)
        webview_update_stylesheets(L, w);

    /* Don't send "finished" signal after "failed" signal */
    if (e == WEBKIT_LOAD_STARTED)
        ((webview_data_t*) w->data)->is_failed = FALSE;
    if (e == WEBKIT_LOAD_FINISHED && ((webview_data_t*) w->data)->is_failed)
        return;

    luaH_object_push(L, w->ref);
    lua_pushstring(L, name);
    luaH_object_emit_signal(L, -2, "load-status", 1, 0);
    lua_pop(L, 1);
}


static GtkWidget*
create_cb(WebKitWebView* UNUSED(v), WebKitNavigationAction* UNUSED(a), widget_t *w)
{
    WebKitWebView *view = NULL;
    widget_t *new;

    lua_State *L = globalconf.L;
    gint top = lua_gettop(L);
    luaH_object_push(L, w->ref);
    gint ret = luaH_object_emit_signal(L, -1, "create-web-view", 0, 1);

    /* check for new webview widget */
    if (ret) {
        if ((new = luaH_towidget(L, -1))) {
            if (new->info->tok == L_TK_WEBVIEW)
                view = WEBKIT_WEB_VIEW(((webview_data_t*)new->data)->view);
            else
                warn("invalid return widget type (expected webview, got %s)",
                        new->info->name);
        } else
            warn("invalid signal return object type (expected webview widget, "
                    "got %s)", lua_typename(L, lua_type(L, -1)));
    }

    lua_settop(L, top);
    return GTK_WIDGET(view);
}

static gboolean
decide_policy_cb(WebKitWebView* UNUSED(v), WebKitPolicyDecision *p,
        WebKitPolicyDecisionType type, widget_t *w)
{
    lua_State *L = globalconf.L;

    switch (type) {
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
      case WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION:
      case WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION:
      {
          gint top = lua_gettop(L);
          WebKitNavigationPolicyDecision *np = WEBKIT_NAVIGATION_POLICY_DECISION(p);
          WebKitNavigationAction *na = webkit_navigation_policy_decision_get_navigation_action(np);
          const gchar *signal_name = type == WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION
                ? "navigation-request" : "new-window-decision";
          const gchar *uri = webkit_uri_request_get_uri(webkit_navigation_action_get_request(na));
          gchar *reason = NULL;

          switch (webkit_navigation_action_get_navigation_type(na)) {
# define NR_CASE(a, l) case WEBKIT_NAVIGATION_TYPE_##a: reason = l; break;
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

          luaH_object_push(L, w->ref);
          lua_pushstring(L, uri);
          lua_pushstring(L, reason);
          gint ret = luaH_object_emit_signal(L, -3, signal_name, 2, 1);
          gboolean ignore = ret && lua_toboolean(L, -1);

          if (ignore)
              webkit_policy_decision_ignore(p);

          lua_settop(L, top);
          return ignore;
      }
      case WEBKIT_POLICY_DECISION_TYPE_RESPONSE:
      {
        // replaces mime_type_decision_cb() in widgets/webview/downloads.c
        WebKitResponsePolicyDecision *rp = WEBKIT_RESPONSE_POLICY_DECISION(p);
        WebKitURIResponse *r = webkit_response_policy_decision_get_response(rp);
        const gchar *uri = webkit_uri_response_get_uri(r);
        const gchar *mime = webkit_uri_response_get_mime_type(r);

        luaH_object_push(L, w->ref);
        lua_pushstring(L, uri);
        lua_pushstring(L, mime);
        gint ret = luaH_object_emit_signal(L, -3, "mime-type-decision", 2, 1);

        gboolean ignore = ret && !lua_toboolean(L, -1);
        if (ignore)
            /* User responded with false, ignore request */
            webkit_policy_decision_ignore(p);
        else if (!webkit_response_policy_decision_is_mime_type_supported(rp))
            webkit_policy_decision_download(p);
        else
            webkit_policy_decision_use(p);

        lua_pop(L, ret + 1);
        return TRUE;
      }
      default:
        break;
    }
    return FALSE;
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

    WebKitFindController *webkit_fc = webkit_web_view_get_find_controller(d->view);
    webkit_find_controller_search_finish(webkit_fc);
    webkit_find_controller_search(webkit_fc, text,
            WEBKIT_FIND_OPTIONS_CASE_INSENSITIVE * (!case_sensitive) |
            WEBKIT_FIND_OPTIONS_BACKWARDS * (!forward) |
            WEBKIT_FIND_OPTIONS_WRAP_AROUND * wrap,
            G_MAXUINT);
    return 0;
}

static gint
luaH_webview_search_next(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    WebKitFindController *webkit_fc = webkit_web_view_get_find_controller(d->view);
    webkit_find_controller_search_next(webkit_fc);
    return 0;
}

static gint
luaH_webview_search_previous(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    WebKitFindController *webkit_fc = webkit_web_view_get_find_controller(d->view);
    webkit_find_controller_search_previous(webkit_fc);
    return 0;
}
static gint
luaH_webview_clear_search(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    WebKitFindController *webkit_fc = webkit_web_view_get_find_controller(d->view);
    webkit_find_controller_search_finish(webkit_fc);
    return 0;
}

/* Proxy for the is_loading property; included for compatibility */
static gint
luaH_webview_loading(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    luaH_gobject_index(L, webview_properties, L_TK_IS_LOADING, G_OBJECT(d->view));
    return 1;
}

static gint
luaH_webview_stop(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    webkit_web_view_stop_loading(d->view);
    return 0;
}

/* check for trusted ssl certificate
* make sure this function is called after WEBKIT_LOAD_COMMITTED
*/
static gint
luaH_webview_ssl_trusted(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    const gchar *uri = webkit_web_view_get_uri(d->view);
    GTlsCertificate *cert;
    GTlsCertificateFlags cert_errors;
    if (uri && d->is_committed &&
            webkit_web_view_get_tls_info(d->view, &cert, &cert_errors)) {
        gboolean is_trusted = (cert_errors == 0);
        lua_pushboolean(L, is_trusted);
        return 1;
    }
    /* return nil if not viewing https uri */
    return 0;
}

static luakit_token_t
webview_translate_old_token(luakit_token_t token)
{
    switch(token) {
      case L_TK_ENABLE_SCRIPTS: return L_TK_ENABLE_JAVASCRIPT;
      default:                  return token;
    }
}

static int
luaH_webview_push_favicon(lua_State *L, WebKitWebView *view)
{
    /* Instantiate a new image widget */
    lua_createtable(L, 0, 1);
    lua_pushliteral(L, "image");
    lua_setfield(L, -2, "type");
    luaH_widget_new(L);
    lua_remove(L, -2);

    cairo_surface_t *favicon = webkit_web_view_get_favicon(view);
    if (!favicon) {
        lua_pushnil(L);
        return 1;
    }

    int width = cairo_image_surface_get_width(favicon);
    int height = cairo_image_surface_get_height(favicon);
    GdkPixbuf *pixbuf = gdk_pixbuf_get_from_surface(favicon, 0, 0, width, height);
    GdkPixbuf *scaled = gdk_pixbuf_scale_simple(pixbuf, 16, 16, GDK_INTERP_BILINEAR);
    g_object_unref(pixbuf);

    widget_t *w = luaH_checkwidget(L, -1);
    gtk_image_set_from_pixbuf(GTK_IMAGE(w->widget), scaled);

    return 1;
}

static void
favicon_cb(WebKitWebView* UNUSED(v), GParamSpec *UNUSED(param_spec), widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "favicon", 0, 0);
    lua_pop(L, 1);
}

static gint
luaH_webview_index(lua_State *L, widget_t *w, luakit_token_t token)
{
    webview_data_t *d = w->data;
    gint ret;

    token = webview_translate_old_token(token);

    switch(token) {
      LUAKIT_WIDGET_INDEX_COMMON(w)
      PB_CASE(INSPECTOR,            d->inspector_open);

      /* push property methods */
      PF_CASE(CLEAR_SEARCH,         luaH_webview_clear_search)
      /* push search methods */
      PF_CASE(SEARCH,               luaH_webview_search)
      PF_CASE(SEARCH_NEXT,          luaH_webview_search_next)
      PF_CASE(SEARCH_PREVIOUS,      luaH_webview_search_previous)
      /* push history navigation methods */
      PF_CASE(GO_BACK,              luaH_webview_go_back)
      PF_CASE(GO_FORWARD,           luaH_webview_go_forward)
      PF_CASE(CAN_GO_BACK,          luaH_webview_can_go_back)
      PF_CASE(CAN_GO_FORWARD,       luaH_webview_can_go_forward)
      /* push misc webview methods */
      PF_CASE(EVAL_JS,              luaH_webview_eval_js)
      PF_CASE(LOAD_STRING,          luaH_webview_load_string)
      /* use is_loading property instead of this function */
      PF_CASE(LOADING,              luaH_webview_loading)
      PF_CASE(RELOAD,               luaH_webview_reload)
      PF_CASE(RELOAD_BYPASS_CACHE,  luaH_webview_reload_bypass_cache)
      PF_CASE(SSL_TRUSTED,          luaH_webview_ssl_trusted)
      PF_CASE(STOP,                 luaH_webview_stop)
      /* push inspector webview methods */
      PF_CASE(SHOW_INSPECTOR,       luaH_webview_show_inspector)
      PF_CASE(CLOSE_INSPECTOR,      luaH_webview_close_inspector)

      /* push string properties */
      PS_CASE(HOVERED_URI,          d->hover)
      PS_CASE(URI,                  d->uri)

      /* push boolean properties */
      // TODO this stopped existing...
      //PB_CASE(VIEW_SOURCE, webkit_web_view_get_view_mode(d->view))

      case L_TK_SESSION_STATE:
        return luaH_webview_push_session_state(L, d);
        return 1;
      case L_TK_STYLESHEETS:
        return luaH_webview_push_stylesheets_table(L);

      PN_CASE(ID, webkit_web_view_get_page_id(d->view))

      case L_TK_HISTORY:
        return luaH_webview_push_history(L, d->view);

      case L_TK_SCROLL:
        return luaH_webview_push_scroll_table(L);

      case L_TK_FAVICON:
        return luaH_webview_push_favicon(L, d->view);

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
luaH_webview_newindex(lua_State *L, widget_t *w, luakit_token_t token)
{
    size_t len;
    webview_data_t *d = w->data;
    gchar *uri;

    token = webview_translate_old_token(token);

    switch(token) {
      LUAKIT_WIDGET_NEWINDEX_COMMON(w)

      case L_TK_URI:
        uri = parse_uri(luaL_checklstring(L, 3, &len));
        webkit_web_view_load_uri(d->view, uri);
        update_uri(w, uri);
        g_free(uri);
        return 0;

      case L_TK_SESSION_STATE:
        luaH_webview_set_session_state(L, d);
        return 0;

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
expose_cb(GtkWidget* UNUSED(widget), cairo_t *UNUSED(e), widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "expose", 0, 0);
    lua_pop(L, 1);
    return FALSE;
}

static void
mouse_target_changed_cb(WebKitWebView* UNUSED(v), WebKitHitTestResult *htr,
        guint UNUSED(modifiers), widget_t *w)
{
    lua_State *L = globalconf.L;
    webview_data_t *d = w->data;
    d->htr_context = webkit_hit_test_result_get_context(htr);

    const char *link = NULL;
    if (webkit_hit_test_result_context_is_link(htr))
        link = webkit_hit_test_result_get_link_uri(htr);

    /* links are identical, do nothing */
    if (d->hover && link && !strcmp(d->hover, link))
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
        luaH_object_emit_signal(L, -1, "property::hovered_uri", 0, 0);
    } else
        d->hover = NULL;

    lua_pop(L, 1);
}

static gint
luaH_push_hit_test(lua_State *L, WebKitWebView* UNUSED(v), widget_t *w)
{
    /* get hit test */
    guint c = ((webview_data_t*) w->data)->htr_context;

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
    HTR_CHECK(EDITABLE,  "editable")
    HTR_CHECK(SCROLLBAR, "scrollbar")

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
    luaH_push_hit_test(L, WEBKIT_WEB_VIEW(view), w);

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
menu_item_cb(GtkAction *action, widget_t *w)
{
    lua_State *L = globalconf.L;
    gpointer ref = g_object_get_data(G_OBJECT(action), "lua_callback");
    luaH_object_push(L, w->ref);
    luaH_object_push(L, ref);
    luaH_dofunction(L, 1, 0);
}

static void
hide_popup_cb(WebKitWebView* UNUSED(v), widget_t* UNUSED(w)) {
    GSList *iter;
    lua_State *L = globalconf.L;

    /* dereference context menu items callback functions from the last
       context menu */
    /* context-menu-dismissed callback gets run before menu_item_cb(),
       causing the lua_callback to not exist if the refs belonging to
       the current context menu are freed during hide_popup_cb(). */
    if (last_popup.old_refs) {
        for (iter = last_popup.old_refs; iter; iter = iter->next)
            luaH_object_unref(L, iter->data);
        g_slist_free(last_popup.old_refs);
        last_popup.old_refs = NULL;
    }
}

static void
context_menu_from_table(lua_State *L, WebKitContextMenu *menu, widget_t *w)
{
    WebKitContextMenuItem *item;
    WebKitContextMenu *submenu;
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
                submenu = webkit_context_menu_new();
                item = webkit_context_menu_item_new_with_submenu(label,
                        submenu);
                webkit_context_menu_append(menu, item);
                context_menu_from_table(L, submenu, w);
                lua_pop(L, 1);

            /* add context menu item */
            } else if(lua_type(L, -1) == LUA_TFUNCTION) {
                GtkAction *action = gtk_action_new(label, label,
                        NULL, NULL);
                item = webkit_context_menu_item_new(action);
                ref = luaH_object_ref(L, -1);
                last_popup.refs = g_slist_prepend(last_popup.refs, ref);
                g_object_set_data(G_OBJECT(action), "lua_callback", ref);

                webkit_context_menu_append(menu, item);
                g_signal_connect(action, "activate",
                        G_CALLBACK(menu_item_cb), (gpointer)w);
            }

        /* add separator if encounters `true` */
        } else if(lua_type(L, -1) == LUA_TBOOLEAN && lua_toboolean(L, -1)) {
            item = webkit_context_menu_item_new_separator();
            webkit_context_menu_append(menu, item);
        }
        lua_pop(L, 1);
    }
}

static gboolean
context_menu_cb(WebKitWebView* UNUSED(v), WebKitContextMenu *menu,
        GdkEvent* UNUSED(e), WebKitHitTestResult* UNUSED(htr), widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    gint ret = luaH_object_emit_signal(L, -1, "populate-popup", 0, 1);
    if (ret && lua_istable(L, -1)) {
        last_popup.old_refs = last_popup.refs;
        last_popup.refs = NULL;
        context_menu_from_table(L, menu, w);
    }
    lua_pop(L, ret + 1);

    return FALSE;
}

static void
webview_destructor(widget_t *w)
{
    webview_data_t *d = w->data;

    g_ptr_array_remove(globalconf.webviews, w);
    gtk_widget_destroy(GTK_WIDGET(d->view));
    g_free(d->uri);
    g_free(d->hover);
    g_slice_free(webview_data_t, d);
}

void
size_request_cb(GtkWidget *UNUSED(widget), GtkRequisition *r, widget_t *w)
{
    gtk_widget_set_size_request(GTK_WIDGET(w->widget), r->width, r->height);
}

void
luakit_uri_scheme_request_cb(WebKitURISchemeRequest *request, gpointer *UNUSED(user_data))
{
    const gchar *uri = webkit_uri_scheme_request_get_uri(request);

    WebKitWebView *view = webkit_uri_scheme_request_get_web_view(request);
    widget_t *w = NULL;

    /* Get the widget corresponding to the web view */
    /* Linear search for now... */
    for (unsigned i = 0; i < globalconf.webviews->len; i++) {
        widget_t *ww = g_ptr_array_index(globalconf.webviews, i);
        webview_data_t *d = ww->data;
        if (d->view == view) {
            w = ww;
            break;
        }
    }
    g_assert(w);

    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    lua_pushstring(L, uri);
    gint ret = luaH_object_emit_signal(L, -2, "luakit-chrome", 1, 1);
    if (ret) {
        GInputStream *gis;
        if (lua_isstring(L, -1)) {
            const gchar *html = lua_tostring(L, -1);
            gis = g_memory_input_stream_new_from_data(html, -1, NULL);
            webkit_uri_scheme_request_finish(request, gis, -1, "text/html");
        } else {
            luaH_warn(L, "luakit_uri_scheme_request_cb(): no return values");
            // TODO better GError*?
            webkit_uri_scheme_request_finish_error(request, NULL);
        }
    }
    lua_pop(L, ret + 1);
    return;
}

gboolean
webview_crashed_cb(WebKitWebView *UNUSED(view), widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "crashed", 0, 0);
    return FALSE;
}

gboolean
webview_wait_for_web_extension_cb(widget_t *w)
{
    if (!globalconf.web_extension_loaded)
        return TRUE;
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    if (!lua_isnil(L, -1))
        luaH_object_emit_signal(L, -1, "web-extension-loaded", 0, 0);
    lua_pop(L, 1);
    return FALSE;
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

    if (!globalconf.stylesheets)
        globalconf.stylesheets = g_ptr_array_new();
    d->stylesheets = NULL;

    /* create widgets */
    d->user_content = webkit_user_content_manager_new();
    d->view = WEBKIT_WEB_VIEW(webkit_web_view_new_with_user_content_manager(d->user_content));
    d->inspector = webkit_web_view_get_inspector(d->view);

    webkit_web_context_set_favicon_database_directory(webkit_web_view_get_context(d->view), NULL);

    d->is_committed = FALSE;

    webkit_web_context_register_uri_scheme(webkit_web_view_get_context(d->view),
            "luakit", (WebKitURISchemeRequestCallback) luakit_uri_scheme_request_cb, NULL, NULL);

    // TODO does scrollbar hiding need to happen here?

    w->widget = GTK_WIDGET(d->view);

    /* insert data into global tables and arrays */
    g_ptr_array_add(globalconf.webviews, w);

    // TODO belongs in widgets/webcontext.c or something
    // replaces download-requested signal
    g_object_connect(G_OBJECT(webkit_web_view_get_context(d->view)),
      "signal::download-started",                     G_CALLBACK(download_start_cb),            w,
      NULL);

    /* connect webview signals */
    g_object_connect(G_OBJECT(d->view),
      LUAKIT_WIDGET_SIGNAL_COMMON(w)
      "signal::button-press-event",                   G_CALLBACK(webview_button_cb),            w,
      "signal::button-release-event",                 G_CALLBACK(webview_button_cb),            w,
      /* create-web-view -> create */
      "signal::create",                               G_CALLBACK(create_cb),                    w,
      /* document-load-finished has no analog in webkit2, but load-changed with
       * the WEBKIT_LOAD_FINISHED event might be what you're looking for. */
      /* download-requested -> WebKitWebContext download-started */
      "signal::web-process-crashed",                  G_CALLBACK(webview_crashed_cb),           w,
      "signal::draw",                                 G_CALLBACK(expose_cb),                    w,
      /* hovering-over-link functionality covered by mouse_target_changed_cb */
      "signal::mouse-target-changed",                 G_CALLBACK(mouse_target_changed_cb),      w,
      "signal::key-press-event",                      G_CALLBACK(key_press_cb),                 w,
      /* {mime-type,navigation,new-window}-policy-decision-requested covered
       * by decide-policy */
      "signal::decide-policy",                        G_CALLBACK(decide_policy_cb),             w,
      "signal::notify",                               G_CALLBACK(notify_cb),                    w,
      /* notify::load-status -> load-changed */
      "signal::load-changed",                         G_CALLBACK(load_changed_cb),              w,
      "signal::load-failed",                          G_CALLBACK(load_failed_cb),               w,
      "signal::load-failed-with-tls-errors",          G_CALLBACK(load_failed_tls_cb),           w,
      /* populate-popup -> context-menu */
      "signal::context-menu",                         G_CALLBACK(context_menu_cb),              w,
      /* unrealize/hide GtkMenu -> context-menu-dismissed WebKitWebView */
      "signal::context-menu-dismissed",               G_CALLBACK(hide_popup_cb),                w,
      /* resource-request-starting -> resource-load-started, but you are
       * no longer allowed to modify the request. This was never used in the
       * original luakit anyway. */
      //"signal::resource-load-started",                G_CALLBACK(resource_load_started_cb),     w,
      "signal::notify::favicon",                      G_CALLBACK(favicon_cb),                   w,
      "signal::authenticate",                         G_CALLBACK(session_authenticate),         w,
      NULL);

    g_object_connect(G_OBJECT(webkit_web_view_get_find_controller(d->view)),
      "signal::found-text",                           G_CALLBACK(found_text_cb),                w,
      "signal::failed-to-find-text",                  G_CALLBACK(failed_to_find_text_cb),       w,
      NULL);

    // TODO was this the right thing to do?
    g_object_connect(G_OBJECT(d->view),
      "signal::parent-set",                           G_CALLBACK(parent_set_cb),                w,
      NULL);

    /* inspect-web-view -> open-window
       show-window -> bring-to-front
       close-window -> close
       attach-window -> attach
       detach-window -> detach */
    g_object_connect(G_OBJECT(d->inspector),
      "signal::attach",                               G_CALLBACK(inspector_attach_window_cb),   w,
      "signal::bring-to-front",                       G_CALLBACK(inspector_show_window_cb),     w,
      "signal::closed",                               G_CALLBACK(inspector_close_window_cb),    w,
      "signal::detach",                               G_CALLBACK(inspector_detach_window_cb),   w,
      "signal::open-window",                          G_CALLBACK(inspector_open_window_cb),     w,
      NULL);

    /* show widgets */
    gtk_widget_show(GTK_WIDGET(d->view));

    g_idle_add((GSourceFunc)webview_wait_for_web_extension_cb, w);

    return w;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
