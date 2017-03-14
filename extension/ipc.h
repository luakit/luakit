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

#ifndef LUAKIT_EXTENSION_IPC_H
#define LUAKIT_EXTENSION_IPC_H

#include "common/ipc.h"

int web_extension_connect(const gchar *socket_path);
void emit_pending_page_creation_ipc(void);

void ipc_recv_lua_require_module(ipc_endpoint_t *from, const ipc_lua_require_module_t *msg, guint length);
void ipc_recv_lua_ipc(ipc_endpoint_t *from, const ipc_lua_ipc_t *msg, guint length);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
