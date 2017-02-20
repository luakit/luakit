#ifndef LUAKIT_EXTENSION_CLIB_EXTENSION_H
#define LUAKIT_EXTENSION_CLIB_EXTENSION_H

#include <webkit2/webkit-web-extension.h>

#include "common/util.h"
#include "common/luaclass.h"
#include "common/luaobject.h"

void extension_class_setup(lua_State *L, WebKitWebExtension *extension);
void extension_class_emit_pending_signals(lua_State *L);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
