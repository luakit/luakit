#ifndef LUAKIT_CLIB_WEB_MODULE_H
#define LUAKIT_CLIB_WEB_MODULE_H

#include "common/msg.h"

void web_module_lib_setup(lua_State *);
void web_module_load_modules_on_endpoint(msg_endpoint_t *ipc);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
