#ifndef LUAKIT_EXTENSION_H
#define LUAKIT_EXTENSION_H

#include <webkit2/webkit-web-extension.h>
#include <lauxlib.h>
#include <lualib.h>

typedef struct _extension_t {
	/** Web Lua VM state */
	lua_State *WL;
	/** Handle to the WebKit Web Extension */
	WebKitWebExtension *ext;
	/** Channel for IPC with ui process */
	GIOChannel *ui_channel;
	/** Isolated JavaScript context */
	WebKitScriptWorld *script_world;
} extension_t;

extension_t extension;

#endif
