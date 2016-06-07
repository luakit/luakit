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
#if WITH_WEBKIT2
    WebKitBackForwardList *bflist = webkit_web_view_get_back_forward_list(view);
    WebKitBackForwardListItem *item;
    // TODO do these new GLists need to be freed?
    gint backlen = g_list_length(
            webkit_back_forward_list_get_back_list(bflist));
    gint forwardlen = g_list_length(
            webkit_back_forward_list_get_forward_list(bflist));
#else
    WebKitWebBackForwardList *bflist = webkit_web_back_forward_list_new_with_web_view(view);
    WebKitWebHistoryItem *item;
    gint backlen = webkit_web_back_forward_list_get_back_length(bflist);
    gint forwardlen = webkit_web_back_forward_list_get_forward_length(bflist);
#endif

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
#if WITH_WEBKIT2
        item = webkit_back_forward_list_get_nth_item(bflist, i);
#else
        item = webkit_web_back_forward_list_get_nth_item(bflist, i);
#endif
        lua_createtable(L, 0, 2);
        /* Set hist_item[uri] = uri */
        lua_pushliteral(L, "uri");
#if WITH_WEBKIT2
        lua_pushstring(L, item ? webkit_back_forward_list_item_get_uri(item) : "about:blank");
#else
        lua_pushstring(L, item ? webkit_web_history_item_get_uri(item) : "about:blank");
#endif
        lua_rawset(L, -3);
        /* Set hist_item[title] = title */
        lua_pushliteral(L, "title");
#if WITH_WEBKIT2
        lua_pushstring(L, item ? webkit_back_forward_list_item_get_title(item) : "");
#else
        lua_pushstring(L, item ? webkit_web_history_item_get_title(item) : "");
#endif
        lua_rawset(L, -3);
        lua_rawseti(L, -2, backlen + i + 1);
    }

    /* Set hist[items] = hist_items_table */
    lua_pushliteral(L, "items");
    lua_insert(L, lua_gettop(L) - 1);
    lua_rawset(L, -3);
    return 1;
}

// TODO this is used to inherit history (say after opening a link in a new tab).
// the current webkit2 API does not allow a WebKitView's WebKitBackForwardList
// to be modified in such a way. Look into an alternative. Perhaps completely
// ignore webkit's backforward list and maintain own copy of history?
// Just remove the API for now; doesn't seem to be used in default install
#if !WITH_WEBKIT2
static void
webview_set_history(lua_State *L, WebKitWebView *view, gint idx)
{
    gint pos, bflen;
#if WITH_WEBKIT2
    WebKitBackForwardList *bflist;
#else
    WebKitWebBackForwardList *bflist;
    WebKitWebHistoryItem *item = NULL;
#endif
    gchar *uri = NULL;

    if(!lua_istable(L, idx))
        luaL_error(L, "invalid history table");

    /* get history items table */
    lua_pushliteral(L, "items");
    lua_rawget(L, idx);
    bflen = lua_objlen(L, -1);

    /* create new back-forward history list */
#if WITH_WEBKIT2
    bflist = webkit_web_view_get_back_forward_list(view);
    // TODO no clearing in webkit2 API
    //webkit_web_back_forward_list_clear(bflist);
#else
    bflist = webkit_web_back_forward_list_new_with_web_view(view);
    webkit_web_back_forward_list_clear(bflist);
#endif

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
#if !WITH_WEBKIT2
            // TODO no adding items either in webkit2 API
            item = webkit_web_history_item_new_with_data(lua_tostring(L, -1), NONULL(lua_tostring(L, -2)));
            webkit_web_back_forward_list_add_item(bflist, item);
#endif
        } else
            uri = g_strdup(lua_tostring(L, -1));
        lua_pop(L, 3);
    }

    /* load last item */
    if (uri) {
        webkit_web_view_load_uri(view, uri);
        g_free(uri);

#if !WITH_WEBKIT2
    /* load item in history */
    } else if (bflen && webkit_web_view_can_go_back_or_forward(view, pos)) {
        webkit_web_view_go_back_or_forward(view, pos);

#endif
    /* load "about:blank" on empty history list */
    } else
        webkit_web_view_load_uri(view, "about:blank");

    lua_pop(L, 1);
}
#endif

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
#if WITH_WEBKIT2
	WebKitBackForwardListItem *item = webkit_back_forward_list_get_nth_item(
			webkit_web_view_get_back_forward_list(d->view), steps);
	if (item)
		webkit_web_view_go_to_back_forward_list_item(d->view, item);
	lua_pushboolean(L, item != NULL);
#else
    gboolean ok = webkit_web_view_can_go_back_or_forward(d->view, steps);
    webkit_web_view_go_back_or_forward(d->view, steps);
	lua_pushboolean(L, ok);
#endif
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

#if WITH_WEBKIT2
static void
webview_set_session_state(webview_data_t *d, gpointer data)
{
    WebKitWebViewSessionState *state = webkit_web_view_session_state_new(data);
    webkit_web_view_restore_session_state(d->view, state);

    WebKitBackForwardList *bfl = webkit_web_view_get_back_forward_list(d->view);
    WebKitBackForwardListItem *item = webkit_back_forward_list_get_current_item(bfl);
    webkit_web_view_go_to_back_forward_list_item(d->view, item);
    update_uri(d->widget, webkit_back_forward_list_item_get_uri(item));
}

static gpointer
webview_get_session_state(webview_data_t *d)
{
    WebKitWebViewSessionState *state = webkit_web_view_get_session_state(d->view);
    return webkit_web_view_session_state_serialize(state);
}
#endif
