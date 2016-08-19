#ifndef LUAKIT_MSG_H
#define LUAKIT_MSG_H

#include "common/msg.h"

typedef struct _msg_endpoint_t {
    /** Channel for IPC with web process */
    GIOChannel *web_channel;
    /** Queued data for when channel is not yet open */
    GByteArray *web_channel_queue;
    /** Whether the web extension is loaded */
    gboolean web_extension_loaded;
} msg_endpoint_t;

void msg_init(void);

void msg_recv_lua_require_module(const msg_lua_require_module_t *UNUSED(msg), guint UNUSED(length));
void msg_recv_lua_msg(const msg_lua_msg_t *msg, guint length);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
