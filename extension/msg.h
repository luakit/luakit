#ifndef LUAKIT_EXTENSION_MSG_H
#define LUAKIT_EXTENSION_MSG_H

#include "common/msg.h"

typedef struct _msg_endpoint_t {
    GIOChannel *channel;
} msg_endpoint_t;

int web_extension_connect(const gchar *socket_path);

void msg_recv_lua_require_module(msg_endpoint_t *from, const msg_lua_require_module_t *msg, guint length);
void msg_recv_lua_msg(msg_endpoint_t *from, const msg_lua_msg_t *msg, guint length);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
