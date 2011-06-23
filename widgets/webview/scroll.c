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

