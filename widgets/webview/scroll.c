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

static gint
luaH_webview_scroll_newindex(lua_State *L)
{
    /* get webview widget upvalue */
    webview_data_t *d = luaH_checkwvdata(L, lua_upvalueindex(1));
    const gchar *prop = luaL_checkstring(L, 2);
    luakit_token_t t = l_tokenize(prop);

    GtkAdjustment *a;
    if (t == L_TK_X)      a = gtk_scrolled_window_get_hadjustment(d->win);
    else if (t == L_TK_Y) a = gtk_scrolled_window_get_vadjustment(d->win);
    else return 0;

    gdouble value = luaL_checknumber(L, 3);
    gdouble max = gtk_adjustment_get_upper(a) -
            gtk_adjustment_get_page_size(a);
    gtk_adjustment_set_value(a, ((value < 0 ? 0 : value) > max ? max : value));
    return 0;
}

static gint
luaH_webview_scroll_index(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, lua_upvalueindex(1));
    const gchar *prop = luaL_checkstring(L, 2);
    luakit_token_t t = l_tokenize(prop);

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
    GObject *frame = G_OBJECT(webkit_web_view_get_main_frame(d->view));

#if GTK_CHECK_VERSION(3,0,0)
    GtkStyleContext* scv = gtk_widget_get_style_context(gtk_scrolled_window_get_vscrollbar(d->win));
    GtkStyleContext* sch = gtk_widget_get_style_context(gtk_scrolled_window_get_hscrollbar(d->win));
    GtkStyleContext* sc = gtk_widget_get_style_context(GTK_WIDGET(d->win));
    GtkStyleProvider* sp = GTK_STYLE_PROVIDER(globalconf.scrollbar_provider);
#endif

    /* show scrollbars */
    if (show) {
        if (d->hide_id)
            g_signal_handler_disconnect(frame, d->hide_id);
#if GTK_CHECK_VERSION(3,0,0)
        gtk_style_context_remove_provider(scv, sp);
        gtk_style_context_remove_provider(sch, sp);
        gtk_style_context_remove_provider(sc, sp);
#else
        gtk_scrolled_window_set_policy(d->win,
                GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
#endif
        d->hide_id = 0;

    /* hide scrollbars */
    } else if (!d->hide_id) {
#if GTK_CHECK_VERSION(3,0,0)
        gtk_style_context_add_provider(scv, sp, GTK_STYLE_PROVIDER_PRIORITY_USER);
        gtk_style_context_add_provider(sch, sp, GTK_STYLE_PROVIDER_PRIORITY_USER);
        gtk_style_context_add_provider(sc, sp, GTK_STYLE_PROVIDER_PRIORITY_USER);
#else
        gtk_scrolled_window_set_policy(d->win,
                GTK_POLICY_NEVER, GTK_POLICY_NEVER);
#endif
        d->hide_id = g_signal_connect(frame, "scrollbars-policy-changed",
                G_CALLBACK(true_cb), NULL);
    }
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
