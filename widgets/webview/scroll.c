/*
 * widgets/webview/scroll.c - webkit webview scroll functions
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

#include "msg.h"

#if WITH_WEBKIT2
static void
scroll_finished(GObject *obj, GAsyncResult *r, gpointer UNUSED(data))
{
    WebKitJavascriptResult *js_result;
    GError *e = NULL;
    js_result = webkit_web_view_run_javascript_finish (WEBKIT_WEB_VIEW(obj), r, &e);
    if (js_result)
        webkit_javascript_result_unref(js_result);
}
#endif

#if !WITH_WEBKIT2
#if GTK_CHECK_VERSION(3,8,0)
gboolean webview_tick_cb(GtkWidget *UNUSED(wi), GdkFrameClock *frame_clock, widget_t *w);

void
webview_set_smoothscroll(widget_t *w, gboolean scrolling)
{
    webview_data_t *d = w->data;

    if (d->smooth_scroll == scrolling)
        return;
    d->smooth_scroll = scrolling;

    if (scrolling)
        d->scroll_cb_id = gtk_widget_add_tick_callback(w->widget, webview_tick_cb, w, NULL);
    else
        gtk_widget_remove_tick_callback(w->widget, d->scroll_cb_id);
}

gfloat
scroll_animate_ease(gfloat a, gfloat b, gfloat p)
{
    return a*(1.0-p) + b*p;
}

gboolean
adjustment_animate_scroll(GtkAdjustment *a, guint duration, guint64 t, webview_scroll_anim_t *s)
{
    gdouble c, max, d;

    /* Clip the target */
    max = gtk_adjustment_get_upper(a) - gtk_adjustment_get_page_size(a);
    max = (max > 0) ? max : 0;
    s->target = s->target > 0 ? s->target : 0;
    s->target = s->target < max ? s->target : max;

    /* Get current value and required scroll direction */
    c = gtk_adjustment_get_value(a);
    d = c < s->target ? 1 : c > s->target ? -1 : 0;

    if (d == 0)
        return false;
    else if (s->start_time == 0)
        s->start_time = t;

    /* Calculate and clip elapsed time */
    guint64 elapsed = (t - s->start_time)/1000;
    if (elapsed >= duration) {
        elapsed = duration;
        s->start_time = 0;
    }

    /* Calculate ease position and ease value */
    gfloat p = elapsed/(gfloat)duration,
           e = scroll_animate_ease(s->source, s->target, p);

    gtk_adjustment_set_value(a, e);

    return elapsed == duration;
}

gboolean
webview_tick_cb(GtkWidget *UNUSED(wi), GdkFrameClock *frame_clock, widget_t *w)
{
    webview_data_t *d = w->data;
    guint64 t = gdk_frame_clock_get_frame_time(frame_clock);
    gboolean done = false;

    GtkAdjustment *ha = gtk_scrolled_window_get_hadjustment(d->win),
                  *va = gtk_scrolled_window_get_vadjustment(d->win);
    done |= adjustment_animate_scroll(ha, d->scroll_time_msec, t, &d->hscroll);
    done |= adjustment_animate_scroll(va, d->scroll_time_msec, t, &d->vscroll);

    if (done)
        webview_set_smoothscroll(w, false);

    return G_SOURCE_CONTINUE;
}
#endif
#endif

void
webview_scroll_recv(widget_t *w, const msg_scroll_t *msg)
{
    webview_data_t *d = w->data;
    if (webkit_web_view_get_page_id(d->view) != msg->page_id)
        return;

    switch (msg->subtype) {
        case MSG_SCROLL_TYPE_docresize:
            d->doc_w = msg->h;
            d->doc_h = msg->v;
            break;
        case MSG_SCROLL_TYPE_winresize:
            d->win_w = msg->h;
            d->win_h = msg->v;
            break;
        case MSG_SCROLL_TYPE_scroll:
            d->scroll_x = msg->h;
            d->scroll_y = msg->v;
        default:
            break;
    }
}

static gint
luaH_webview_scroll_newindex(lua_State *L)
{
    /* get webview widget upvalue */
    webview_data_t *d = luaH_checkwvdata(L, lua_upvalueindex(1));
    const gchar *prop = luaL_checkstring(L, 2);
    luakit_token_t t = l_tokenize(prop);

#if WITH_WEBKIT2
    gchar *script;
    gint value = luaL_checknumber(L, 3);
    if (t == L_TK_X) {
        if (value == -1)
            script = g_strdup_printf("window.scrollTo(window.document.width, window.scrollY)");
        else
            script = g_strdup_printf("window.scrollTo(%d, window.scrollY)", value);
    } else if (t == L_TK_Y) {
        if (value == -1)
            script = g_strdup_printf("window.scrollTo(window.scrollX, window.document.height)");
        else
            script = g_strdup_printf("window.scrollTo(window.scrollX, %d)", value);
    } else if (t == L_TK_XREL)
        script = g_strdup_printf("window.scrollBy(%d, 0)", value);
    else if (t == L_TK_YREL)
        script = g_strdup_printf("window.scrollBy(0, %d)", value);
    else if (t == L_TK_XPAGE)
        script = g_strdup_printf("window.scrollTo(window.innerWidth*%d, window.scrollY)", value);
    else if (t == L_TK_YPAGE)
        script = g_strdup_printf("window.scrollTo(window.scrollX, window.innerHeight*%d)", value);
    else if (t == L_TK_XPAGEREL)
        script = g_strdup_printf("window.scrollBy(window.innerWidth*%d, 0)", value);
    else if (t == L_TK_YPAGEREL)
        script = g_strdup_printf("window.scrollBy(0, window.innerHeight*%d)", value);
    else if (t == L_TK_XPCT)
        script = g_strdup_printf("window.scrollTo((window.document.width - window.innerWidth)*%d/100, window.scrollY)", value);
    else if (t == L_TK_YPCT)
        script = g_strdup_printf("window.scrollTo(window.scrollX, (window.document.height - window.innerHeight)*%d/100)", value);
    else
        return 0;
    webkit_web_view_run_javascript(d->view, script, NULL, scroll_finished, NULL);
    g_free(script);
#else
    /* Get the adjustment for the scroll */
    GtkAdjustment *a;
    if (t == L_TK_X)      a = gtk_scrolled_window_get_hadjustment(d->win);
    else if (t == L_TK_Y) a = gtk_scrolled_window_get_vadjustment(d->win);
    else return 0;

#if GTK_CHECK_VERSION(3,8,0)
    webview_scroll_anim_t *anim = t == L_TK_X ? &d->hscroll : &d->vscroll;
    anim->source = gtk_adjustment_get_value(a);
    anim->target = luaL_checknumber(L, 3);
    anim->start_time = 0;

    webview_set_smoothscroll(d->widget, true);
#else
    gdouble value = luaL_checknumber(L, 3);
    gdouble max = gtk_adjustment_get_upper(a) -
            gtk_adjustment_get_page_size(a);
    // https://git.gnome.org/browse/hyena/commit/?id=0745bfb75809886925dfa49a57c79e5f71565d08
    max = (max > 0) ? max : 0;
    gtk_adjustment_set_value(a, ((value < 0 ? 0 : value) > max ? max : value));
#endif
#endif

    return 0;
}

void
webview_scroll_init(widget_t *w)
{
    /* Load scroll animation duration */
    webview_data_t *d = w->data;
    lua_State *L = globalconf.L;
    lua_getglobal(L, "scroll_duration_msec");
    d->scroll_time_msec = lua_tonumber(L, -1) ?: 500;
    lua_pop(L, 1);
}

static gint
luaH_webview_scroll_index(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, lua_upvalueindex(1));
    const gchar *prop = luaL_checkstring(L, 2);
    luakit_token_t t = l_tokenize(prop);

#if WITH_WEBKIT2
    // TODO
    switch (t) {
        PN_CASE(X, d->scroll_x);
        PN_CASE(Y, d->scroll_y);
        PN_CASE(XMAX, d->doc_w - d->win_w);
        PN_CASE(YMAX, d->doc_h - d->win_h);
        PN_CASE(XPAGE_SIZE, d->win_w);
        PN_CASE(YPAGE_SIZE, d->win_h);
        default:
            return 0;
    }
#else
    GtkAdjustment *a = (*prop == 'x') ?
              gtk_scrolled_window_get_hadjustment(d->win)
            : gtk_scrolled_window_get_vadjustment(d->win);

    if (t == L_TK_X || t == L_TK_Y) {
        lua_pushnumber(L, gtk_adjustment_get_value(a));
        return 1;

    } else if (t == L_TK_XMAX || t == L_TK_YMAX) {
        lua_pushnumber(L, gtk_adjustment_get_upper(a) -
                gtk_adjustment_get_page_size(a));
        return 1;

    } else if (t == L_TK_XPAGE_SIZE || t == L_TK_YPAGE_SIZE) {
        lua_pushnumber(L, gtk_adjustment_get_page_size(a));
        return 1;
    }
    return 0;
#endif
}

static gint
luaH_webview_push_scroll_table(lua_State *L)
{
    /* create scroll table */
    lua_newtable(L);
    /* setup metatable */
    lua_createtable(L, 0, 2);
    /* push __index metafunction */
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, 1); /* copy webview userdata */
    lua_pushcclosure(L, luaH_webview_scroll_index, 1);
    lua_rawset(L, -3);
    /* push __newindex metafunction */
    lua_pushliteral(L, "__newindex");
    lua_pushvalue(L, 1); /* copy webview userdata */
    lua_pushcclosure(L, luaH_webview_scroll_newindex, 1);
    lua_rawset(L, -3);
    lua_setmetatable(L, -2);
    return 1;
}

void
show_scrollbars(webview_data_t *d, gboolean show)
{
    // TODO
#if !WITH_WEBKIT2
    GObject *frame = G_OBJECT(webkit_web_view_get_main_frame(d->view));

    /* show scrollbars */
    if (show) {
        if (d->hide_id)
            g_signal_handler_disconnect(frame, d->hide_id);
#if GTK_CHECK_VERSION(3,0,0)
        gtk_scrolled_window_set_policy(d->win,
                GTK_POLICY_ALWAYS, GTK_POLICY_ALWAYS);

        GtkWidget *hscroll = gtk_scrolled_window_get_hscrollbar(d->win);
        GtkWidget *vscroll = gtk_scrolled_window_get_vscrollbar(d->win);

        gtk_widget_show(hscroll);
        gtk_widget_show(vscroll);
#else
        gtk_scrolled_window_set_policy(d->win,
                GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
#endif
        d->hide_id = 0;

    /* hide scrollbars */
    } else if (!d->hide_id) {
#if GTK_CHECK_VERSION(3,0,0)
        GtkWidget *hscroll = gtk_scrolled_window_get_hscrollbar(d->win);
        GtkWidget *vscroll = gtk_scrolled_window_get_vscrollbar(d->win);

        gtk_widget_hide(hscroll);
        gtk_widget_hide(vscroll);

        gtk_scrolled_window_set_shadow_type(d->win, GTK_SHADOW_NONE);

        d->hide_id = 1; // TODO
#else
        gtk_scrolled_window_set_policy(d->win,
                GTK_POLICY_NEVER, GTK_POLICY_NEVER);
        d->hide_id = g_signal_connect(frame, "scrollbars-policy-changed",
                G_CALLBACK(true_cb), NULL);
#endif
    }
#endif
}
