#ifndef LUAKIT_EXTENSION_MSG_H
#define LUAKIT_EXTENSION_MSG_H

#include "common/msg.h"

int web_extension_connect(const gchar *socket_path);
void emit_pending_page_creation_ipc(void);

void msg_recv_lua_require_module(msg_endpoint_t *from, const msg_lua_require_module_t *msg, guint length);
void msg_recv_lua_msg(msg_endpoint_t *from, const msg_lua_msg_t *msg, guint length);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
