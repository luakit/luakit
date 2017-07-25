/*
 * widgets/webview/history.c - webkit webview history functions
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
luaH_webview_push_history(lua_State *L, WebKitWebView *view)
{
    /* obtain the history list of the tab and get information about it */
    WebKitBackForwardList *bflist = webkit_web_view_get_back_forward_list(view);
    WebKitBackForwardListItem *item;
    // TODO do these new GLists need to be freed?
    gint backlen = g_list_length(
            webkit_back_forward_list_get_back_list(bflist));
    gint forwardlen = g_list_length(
            webkit_back_forward_list_get_forward_list(bflist));

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
        item = webkit_back_forward_list_get_nth_item(bflist, i);
        lua_createtable(L, 0, 2);
        /* Set hist_item[uri] = uri */
        lua_pushliteral(L, "uri");
        lua_pushstring(L, item ? webkit_back_forward_list_item_get_uri(item) : "about:blank");
        lua_rawset(L, -3);
        /* Set hist_item[title] = title */
        lua_pushliteral(L, "title");
        lua_pushstring(L, item ? webkit_back_forward_list_item_get_title(item) : "");
        lua_rawset(L, -3);
        lua_rawseti(L, -2, backlen + i + 1);
    }

    /* Set hist[items] = hist_items_table */
    lua_pushliteral(L, "items");
    lua_insert(L, lua_gettop(L) - 1);
    lua_rawset(L, -3);
    return 1;
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
webview_history_go(lua_State *L, gint direction)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    gint steps = (gint) luaL_checknumber(L, 2) * direction;
    WebKitBackForwardListItem *item = webkit_back_forward_list_get_nth_item(
            webkit_web_view_get_back_forward_list(d->view), steps);
    if (item)
        webkit_web_view_go_to_back_forward_list_item(d->view, item);
    lua_pushboolean(L, item != NULL);
    return 1;
}

static gint
luaH_webview_go_back(lua_State *L)
{
    return webview_history_go(L, -1);
}

static gint
luaH_webview_go_forward(lua_State *L)
{
    return webview_history_go(L,  1);
}

static void
luaH_webview_set_session_state(lua_State *L, webview_data_t *d)
{
    size_t len;
    const gchar *str = lua_tolstring(L, 3, &len);
    GBytes *bytes = g_bytes_new(str, len);
    WebKitWebViewSessionState *state = webkit_web_view_session_state_new(bytes);
    g_bytes_unref(bytes);
    if (!state)
        luaL_error(L, "Invalid session state");
    webkit_web_view_restore_session_state(d->view, state);
    webkit_web_view_session_state_unref(state);

    WebKitBackForwardList *bfl = webkit_web_view_get_back_forward_list(d->view);
    WebKitBackForwardListItem *item = webkit_back_forward_list_get_current_item(bfl);
    if (item) {
        webkit_web_view_go_to_back_forward_list_item(d->view, item);
        update_uri(d->widget, webkit_back_forward_list_item_get_uri(item));
    }
}

static int
luaH_webview_push_session_state(lua_State *L, webview_data_t *d)
{
    WebKitWebViewSessionState *state = webkit_web_view_get_session_state(d->view);
    GBytes *bytes = webkit_web_view_session_state_serialize(state);
    gsize len;
    const gchar *str = g_bytes_get_data(bytes, &len);
    lua_pushlstring(L, str, len);
    g_bytes_unref(bytes);
    webkit_web_view_session_state_unref(state);
    return 1;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
