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
