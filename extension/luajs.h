/*
 * Copyright © 2016 Aidan Holm <aidanholm@gmail.com>
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

#ifndef LUAKIT_EXTENSION_LUAJS_H
#define LUAKIT_EXTENSION_LUAJS_H

#include <glib.h>
#include <jsc/jsc.h>

void web_luajs_init(void);
void luaJS_register_function(lua_State *L);
void ipc_recv_lua_js_call(ipc_endpoint_t *from, const guint8 *msg, guint length);
void ipc_recv_lua_js_register(ipc_endpoint_t *from, const guint8 *msg, guint length);

/* JavaScript context cache (avoids deprecated webkit_web_page_get_main_frame) */
JSCContext *js_context_cache_get(guint64 page_id);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
