#ifndef LUAKIT_EXTENSION_LUAJS_H
#define LUAKIT_EXTENSION_LUAJS_H

#include <glib.h>

void web_luajs_init(void);
void msg_recv_lua_js_call(const guint8 *msg, guint length);
void msg_recv_lua_js_register(const guint8 *msg, guint length);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
