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
#include "extension/clib/page.h"
#include "common/ipc.h"
#include "common/lualib.h"
#include "common/luaserialize.h"
#include "common/luajs.h"

typedef struct _luajs_func_ctx_t {
    gpointer ref;
    guint64 page_id;
} luajs_func_ctx_t;

static gint lua_string_find_ref = LUA_REFNIL;
static JSClassRef promise_executor_cb_class;
static JSClassRef luaJS_registered_function_callback_class;

static JSObjectRef
js_make_closure(JSContextRef context, JSClassRef callback_class, gpointer user_data)
{
    g_assert(context);
    g_assert(callback_class);
    return JSObjectMake(context, callback_class, user_data);
}

typedef struct _js_promise_t {
    JSObjectRef promise;
    JSObjectRef resolve;
    JSObjectRef reject;
} js_promise_t;

static JSValueRef
promise_executor_cb(JSContextRef context, JSObjectRef function, JSObjectRef UNUSED(thisObject), size_t argc, const JSValueRef argv[], JSValueRef *UNUSED(exception))
{
    g_assert_cmpint(argc,==,2);
    JSObjectRef resolve = JSValueToObject(context, argv[0], NULL),
                reject = JSValueToObject(context, argv[1], NULL);
    g_assert(JSObjectIsFunction(context, resolve));
    g_assert(JSObjectIsFunction(context, reject));

    js_promise_t *promise = JSObjectGetPrivate(function);

    JSValueProtect(context, resolve);
    JSValueProtect(context, reject);
    promise->resolve = resolve;
    promise->reject = reject;

    return JSValueMakeUndefined(context);
}

static void
new_promise(JSContextRef context, js_promise_t *promise)
{
    /* Get the Promise() constructor */
    JSObjectRef global = JSContextGetGlobalObject(context);
    JSStringRef key = JSStringCreateWithUTF8CString("Promise");
    JSObjectRef promise_ctor = JSValueToObject(context, JSObjectGetProperty(context, global, key, NULL), NULL);
    JSStringRelease(key);
    g_assert(JSObjectIsConstructor(context, promise_ctor));

    JSValueRef argv[] = { js_make_closure(context, promise_executor_cb_class, promise) };
    promise->promise = JSObjectCallAsConstructor(context, promise_ctor, 1, argv, NULL);
}

static int
luaJS_promise_resolve_reject(lua_State *L)
{
    guint64 page_id = lua_tointeger(L, lua_upvalueindex(1));
    WebKitWebPage *page = webkit_web_extension_get_page(extension.ext, page_id);
    if (!page || !WEBKIT_IS_WEB_PAGE(page))
        return luaL_error(L, "promise no longer valid (associated page closed)");
    JSGlobalContextRef context = webkit_frame_get_javascript_global_context(
            webkit_web_page_get_main_frame(page));

    js_promise_t *promise = (js_promise_t*)lua_topointer(L, lua_upvalueindex(2));
    JSObjectRef cb = lua_toboolean(L, lua_upvalueindex(3)) ? promise->resolve : promise->reject;

    JSValueRef ret = luaJS_tovalue(L, context, 1, NULL);

    JSObjectCallAsFunction(context, cb, NULL, 1, &ret, NULL);
    g_slice_free(js_promise_t, promise);
    return 0;
}

static JSValueRef
luaJS_registered_function_callback(JSContextRef context, JSObjectRef fun,
        JSObjectRef UNUSED(this), size_t argc, const JSValueRef *argv,
        JSValueRef *exception)
{
    lua_State *L = common.L;
    gint top = lua_gettop(L);
    luajs_func_ctx_t *ctx = JSObjectGetPrivate(fun);

    /* Make promise */
    js_promise_t *promise = g_slice_new(js_promise_t);
    new_promise(context, promise);

    luaH_page_from_web_page(L, webkit_web_extension_get_page(extension.ext, ctx->page_id));

    lua_pushinteger(L, ctx->page_id);
    lua_pushlightuserdata(L, promise);
    lua_pushboolean(L, TRUE);
    lua_pushcclosure(L, luaJS_promise_resolve_reject, 3);

    lua_pushinteger(L, ctx->page_id);
    lua_pushlightuserdata(L, promise);
    lua_pushboolean(L, FALSE);
    lua_pushcclosure(L, luaJS_promise_resolve_reject, 3);

    /* push function arguments onto Lua stack */
    for (guint i = 0; i < argc; i++) {
        gchar *error = NULL;
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

    /* TODO: handle callback failure? */
    luaH_object_push(L, ctx->ref);
    luaH_dofunction(L, argc + 3, 0);

    lua_settop(L, top);
    return promise->promise;
}

void
luaJS_register_function(lua_State *L)
{
    g_assert(lua_isstring(L, -3));
    g_assert(lua_isstring(L, -2));
    g_assert(lua_isfunction(L, -1));

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

    /* Shift the table down, and set it */
    lua_insert(L, -3);
    lua_rawset(L, -3);
    lua_pop(L, 2);
}

static void register_func(WebKitScriptWorld *world, WebKitWebPage *web_page, WebKitFrame *frame, const gchar *name, gpointer ref)
{
    JSGlobalContextRef context = webkit_frame_get_javascript_context_for_script_world(frame, world);
    luajs_func_ctx_t *ctx = g_slice_new(luajs_func_ctx_t);
    ctx->page_id = webkit_web_page_get_id(web_page);
    ctx->ref = ref;
    JSObjectRef fun = js_make_closure(context, luaJS_registered_function_callback_class, ctx);

    JSStringRef js_name = JSStringCreateWithUTF8CString(name);
    JSObjectRef global = JSContextGetGlobalObject(context);
    JSObjectSetProperty(context, global, js_name, fun,
            kJSPropertyAttributeDontDelete | kJSPropertyAttributeReadOnly, NULL);
    JSStringRelease(js_name);
}

static void
window_object_cleared_cb(WebKitScriptWorld *world, WebKitWebPage *web_page, WebKitFrame *frame, gpointer UNUSED(user_data))
{
    if (!webkit_frame_is_main_frame(frame))
        return;

    lua_State *L = common.L;
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
                g_assert(lua_isfunction(L, -1));
                gpointer ref = luaH_object_ref(L, -1);
                register_func(world, web_page, frame, lua_tostring(L, -1), ref);
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
    lua_State *L = common.L;
    lua_pushliteral(L, LUAKIT_LUAJS_REGISTRY_KEY);
    lua_newtable(L);
    lua_rawset(L, LUA_REGISTRYINDEX);

    /* Save reference to string.find() */
    lua_getglobal(L, "string");
    lua_getfield(L, -1, "find");
    luaH_registerfct(L, -1, &lua_string_find_ref);
    lua_pop(L, 2);

    /* Create callback classes */
    JSClassDefinition def;
    def = kJSClassDefinitionEmpty;
    def.callAsFunction = promise_executor_cb;
    promise_executor_cb_class = JSClassCreate(&def);
    def = kJSClassDefinitionEmpty;
    def.callAsFunction = luaJS_registered_function_callback;
    luaJS_registered_function_callback_class = JSClassCreate(&def);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
