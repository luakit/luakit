/*
 * widgets/webview/find_controller.c - WebKitFindController wrappers
 *
 * Copyright © 2012 Mason Larobina <mason.larobina@gmail.com>
 * Copyright © 2011-2012 Fabian Streitel <karottenreibe@gmail.com>
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

static void
found_text_cb(WebKitFindController* UNUSED(find_controller), guint match_count,
        widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    lua_pushinteger(L, match_count);
    luaH_object_emit_signal(L, -2, "found-text", 1, 0);
    lua_pop(L, 1);
    return;
}

static void
failed_to_find_text_cb(WebKitFindController* UNUSED(find_controller),
        widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "failed-to-find-text", 0, 0);
    lua_pop(L, 1);
    return;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
