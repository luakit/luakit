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

#include "ipc.h"

void
webview_scroll_recv(widget_t *w, const ipc_scroll_t *msg)
{
    webview_data_t *d = w->data;
    if (webkit_web_view_get_page_id(d->view) != msg->page_id)
        return;

    switch (msg->subtype) {
        case IPC_SCROLL_TYPE_docresize:
            d->doc_w = msg->h;
            d->doc_h = msg->v;
            break;
        case IPC_SCROLL_TYPE_winresize:
            d->win_w = msg->h;
            d->win_h = msg->v;
            break;
        case IPC_SCROLL_TYPE_scroll:
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

    if (t == L_TK_X)
        d->scroll_x = luaL_checknumber(L, 3);
    else if (t == L_TK_Y)
        d->scroll_y = luaL_checknumber(L, 3);
    else {
        return 0;
    }

    lua_pushinteger(L, webkit_web_view_get_page_id(d->view));
    lua_pushinteger(L, d->scroll_x);
    lua_pushinteger(L, d->scroll_y);
    ipc_send_lua(d->ipc, IPC_TYPE_scroll, L, 4, 6);

    return 0;
}

static gint
luaH_webview_scroll_index(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, lua_upvalueindex(1));
    const gchar *prop = luaL_checkstring(L, 2);
    luakit_token_t t = l_tokenize(prop);

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

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
