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

#include <JavaScriptCore/JavaScript.h>
#include <unistd.h>

#define LUAKIT_LUAJS_REGISTRY_KEY "luakit.luajs.registry"

#include "luah.h"
#include "extension/extension.h"
#include "extension/luajs.h"
#include "common/msg.h"
#include "common/lualib.h"
#include "common/luaserialize.h"
#include "common/luajs.h"

static void register_func(WebKitScriptWorld *world, WebKitWebPage *web_page, WebKitFrame *frame, const gchar *name, gpointer ref);

static void
lua_gc_stack_top(lua_State *L)
{
    msg_send_lua(extension.ipc, MSG_TYPE_lua_js_gc, L, -1, -1);
}

typedef struct _luajs_func_ctx_t {
    gpointer ref;
    guint64 page_id;
} luajs_func_ctx_t;

static gint lua_string_find_ref = LUA_REFNIL;

static JSValueRef
luaJS_registered_function_callback(JSContextRef context, JSObjectRef fun,
        JSObjectRef UNUSED(this), size_t argc, const JSValueRef *argv,
        JSValueRef *exception)
{
    lua_State *L = extension.WL;
    gint top = lua_gettop(L);
    gchar *error = NULL;

    /* Push view id, function ref onto Lua stack */
    luajs_func_ctx_t *ctx = JSObjectGetPrivate(fun);
    lua_pushinteger(L, ctx->page_id);
    lua_pushlightuserdata(L, ctx->ref);

    /* push function arguments onto Lua stack */
    for (guint i = 0; i < argc; i++) {
        if (luaJS_pushvalue(L, context, argv[i], &error))
            continue;

        /* raise JavaScript exception */
        gchar *emsg = g_strdup_printf("bad argument #%d to Lua function (%s)",
                i, error);
        *exception = luaJS_make_exception(context, emsg);
        g_free(error);
        g_free(emsg);
        lua_settop(L, top);
        return JSValueMakeUndefined(context);
    }

    /* Notify UI process of function call... */
    msg_send_lua(extension.ipc, MSG_TYPE_lua_js_call, L, top+1, -1);

    /* ...and block until it's replied */
    do {
        usleep(1);
    } while(!msg_recv_and_dispatch_or_enqueue(extension.ipc, MSG_TYPE_lua_js_call));

    /* At this point, reply was just handled in msg_recv_lua_js_call() below */

    JSValueRef ret = NULL;

    if (lua_toboolean(L, -1))
        error = g_strdup(luaL_checkstring(L, -2));
    else
        ret = luaJS_tovalue(L, context, -2, &error);

    /* invalid return type from registered function */
    if (error) {
        *exception = luaJS_make_exception(context, error);
        ret = JSValueMakeUndefined(context);
        g_free(error);
    }

    lua_settop(L, top);
    return ret;
}

void
msg_recv_lua_js_call(msg_endpoint_t *UNUSED(ipc), const guint8 *msg, guint length)
{
    lua_State *L = extension.WL;
    int n = lua_deserialize_range(L, msg, length);
    /* Should have two values: arbitrary return value, and ok/err status */
    g_assert_cmpint(n, ==, 2);
    g_assert(lua_isboolean(L, -1));
}

void
msg_recv_lua_js_register(msg_endpoint_t *UNUSED(ipc), const guint8 *msg, guint length)
{
    lua_State *L = extension.WL;

    /* Should have three values: pattern, function name, function ref */
    int n = lua_deserialize_range(L, msg, length);
    g_assert_cmpint(n, ==, 3);
    g_assert(lua_isstring(L, -3));
    g_assert(lua_isstring(L, -2));
    g_assert(lua_islightuserdata(L, -1));

    /* push pattern_table[pattern] */
    lua_pushliteral(L, LUAKIT_LUAJS_REGISTRY_KEY);
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushvalue(L, -4);
    lua_rawget(L, -2);

    /* If table[pattern] is nil, set it to an empty table */
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        /* Push key, {}, and set the value */
        lua_pushvalue(L, -4);
        lua_newtable(L);
        lua_rawset(L, -3);
        /* Push key, and get the newly-set value */
        lua_pushvalue(L, -4);
        lua_rawget(L, -2);
    }

    lua_replace(L, -2);

    /* If that function is already registered, free it */
    lua_pushvalue(L, -3);
    lua_rawget(L, -2);
    if (!lua_isnil(L, -1)) {
        g_assert(lua_islightuserdata(L, -1));
        lua_gc_stack_top(L);
    }
    lua_pop(L, 1);

    /* Shift the table down, and set it */
    lua_insert(L, -3);
    lua_rawset(L, -3);
    lua_pop(L, 2);
}

static void
luaJS_registered_function_gc(JSObjectRef obj)
{
    luajs_func_ctx_t *ctx = JSObjectGetPrivate(obj);
    g_slice_free(luajs_func_ctx_t, ctx);
}

static void register_func(WebKitScriptWorld *world, WebKitWebPage *web_page, WebKitFrame *frame, const gchar *name, gpointer ref)
{
    JSGlobalContextRef context = webkit_frame_get_javascript_context_for_script_world(frame, world);

    JSStringRef js_name = JSStringCreateWithUTF8CString(name);
    JSClassDefinition def = kJSClassDefinitionEmpty;
    def.callAsFunction = luaJS_registered_function_callback;
    def.className = g_strdup(name);
    def.finalize = luaJS_registered_function_gc;
    JSClassRef class = JSClassCreate(&def);

    luajs_func_ctx_t *ctx = g_slice_new(luajs_func_ctx_t);
    ctx->page_id = webkit_web_page_get_id(web_page);
    ctx->ref = ref;

    JSObjectRef fun = JSObjectMake(context, class, ctx);
    JSObjectRef global = JSContextGetGlobalObject(context);
    JSObjectSetProperty(context, global, js_name, fun,
            kJSPropertyAttributeDontDelete | kJSPropertyAttributeReadOnly, NULL);

    JSStringRelease(js_name);
    JSClassRelease(class);
}

static void
window_object_cleared_cb(WebKitScriptWorld *world, WebKitWebPage *web_page, WebKitFrame *frame, gpointer UNUSED(user_data))
{
    lua_State *L = extension.WL;
    const gchar *uri = webkit_web_page_get_uri(web_page) ?: "about:blank";

    /* Push pattern -> funclist table */
    lua_pushliteral(L, LUAKIT_LUAJS_REGISTRY_KEY);
    lua_rawget(L, LUA_REGISTRYINDEX);

    /* Iterate over all patterns */
    lua_pushnil(L);
    while (lua_next(L, -2) != 0) {
        /* Entries must be string -> function-list */
        g_assert(lua_isstring(L, -2));
        g_assert(lua_istable(L, -1));

        /* Call string.find(uri, pattern) */
        lua_pushstring(L, uri);
        lua_pushvalue(L, -3);
        luaH_dofunction_from_registry(L, lua_string_find_ref, 2, 1);

        if (!lua_isnil(L, -1)) {
            /* got a match: iterate over all functions */
            lua_pushnil(L);
            while (lua_next(L, -3) != 0) {
                /* Entries must be name -> ref */
                g_assert(lua_isstring(L, -2));
                g_assert(lua_islightuserdata(L, -1));
                /* Register the function */
                register_func(world, web_page, frame, lua_tostring(L, -2), lua_touserdata(L, -1));
                lua_pop(L, 1);
            }
        }

        /* Pop off return code and the function value */
        lua_pop(L, 2);
    }

    /* Pop off table and string.find() */
    lua_pop(L, 1);
}

void
web_luajs_init(void)
{
    g_signal_connect(webkit_script_world_get_default(), "window-object-cleared",
            G_CALLBACK (window_object_cleared_cb), NULL);

    /* Push empty function registration table */
    lua_State *L = extension.WL;
    lua_pushliteral(L, LUAKIT_LUAJS_REGISTRY_KEY);
    lua_newtable(L);
    lua_rawset(L, LUA_REGISTRYINDEX);

    /* Save reference to string.find() */
    lua_getglobal(L, "string");
    lua_getfield(L, -1, "find");
    luaH_registerfct(L, -1, &lua_string_find_ref);
    lua_pop(L, 2);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
