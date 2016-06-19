#ifndef LUAKIT_COMMON_LUAJS_H
#define LUAKIT_COMMON_LUAJS_H

#include <JavaScriptCore/JavaScript.h>
#include <stdlib.h>
#include <glib.h>
#include <lua.h>

gchar* tostring(JSContextRef context, JSValueRef value, gchar **error);
gint luaJS_pushstring(lua_State *L, JSContextRef context, JSValueRef value, gchar **error);
gint luaJS_pushobject(lua_State *L, JSContextRef context, JSObjectRef obj, gchar **error);
gint luaJS_pushvalue(lua_State *L, JSContextRef context, JSValueRef value, gchar **error);
JSValueRef luaJS_fromtable(lua_State *L, JSContextRef context, gint idx, gchar **error);
JSValueRef luaJS_tovalue(lua_State *L, JSContextRef context, gint idx, gchar **error);
JSValueRef luaJS_make_exception(JSContextRef context, const gchar *error);

gint luaJS_eval_js(lua_State *L, JSContextRef context, const gchar *script, const gchar *source, bool no_return);

#endif /* end of include guard: LUAKIT_COMMON_LUAJS_H */
