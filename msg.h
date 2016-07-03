#ifndef LUAKIT_MSG_H
#define LUAKIT_MSG_H

#include "common/msg.h"

void msg_init(void);

void msg_recv_lua_require_module(const msg_lua_require_module_t *UNUSED(msg), guint UNUSED(length));
void msg_recv_lua_msg(const msg_lua_msg_t *msg, guint length);

#endif
