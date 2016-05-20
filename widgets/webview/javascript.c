/*
 * widgets/webview/javascript.c - webkit webview javascript functions
 *
 * Copyright © 2010-2012 Mason Larobina <mason.larobina@gmail.com>
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
#include <stdlib.h>

#include "common/luajs.h"

static JSValueRef
luaJS_registered_function_callback(JSContextRef context, JSObjectRef fun,
        JSObjectRef UNUSED(this), size_t argc, const JSValueRef *argv,
        JSValueRef *exception)
{
    lua_State *L = globalconf.L;
    gint top = lua_gettop(L);

    /* push Lua callback function */
    luaH_object_push(L, JSObjectGetPrivate(fun));

    gchar *error = NULL;
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

    if (lua_pcall(L, argc, 1, 0)) {
        /* raise JS exception with Lua error message */
        const gchar *error = luaL_checkstring(L, -1);
        lua_pop(L, 1);
        *exception = luaJS_make_exception(context, error);
        return JSValueMakeUndefined(context);
    }

    JSValueRef ret = luaJS_tovalue(L, context, -1, &error);
    lua_pop(L, 1);

    /* invalid return type from registered function */
    if (error) {
        *exception = luaJS_make_exception(context, error);
        return JSValueMakeUndefined(context);
    }

    return ret;
}

static void
luaJS_registered_function_gc(JSObjectRef obj)
{
    gpointer userfunc = JSObjectGetPrivate(obj);
    luaH_object_unref(globalconf.L, userfunc);
}

static void
luaJS_register_function(JSContextRef context, const gchar *name, gpointer ref)
{
    JSStringRef js_name = JSStringCreateWithUTF8CString(name);

    JSClassDefinition def = kJSClassDefinitionEmpty;
    def.callAsFunction = luaJS_registered_function_callback;
    def.className = g_strdup(name);
    def.finalize = luaJS_registered_function_gc;
    JSClassRef class = JSClassCreate(&def);

    JSObjectRef fun = JSObjectMake(context, class, ref);
    JSObjectRef global = JSContextGetGlobalObject(context);
    JSObjectSetProperty(context, global, js_name, fun,
            kJSPropertyAttributeDontDelete | kJSPropertyAttributeReadOnly, NULL);

    JSStringRelease(js_name);
    JSClassRelease(class);
}

#if !WITH_WEBKIT2
static gint
luaJS_eval_js(lua_State *L, JSContextRef context, const gchar *script,
        const gchar *source, bool no_return)
{

    JSStringRef js_source, js_script;
    JSValueRef result, exception = NULL;

    /* evaluate the script and get return value*/
    js_script = JSStringCreateWithUTF8CString(script);
    js_source = JSStringCreateWithUTF8CString(source);

    result = JSEvaluateScript(context, js_script, NULL, js_source, 0, &exception);

    /* cleanup */
    JSStringRelease(js_script);
    JSStringRelease(js_source);

    /* handle javascript exceptions while running script */
    if (exception) {
        lua_pushnil(L);
        if (!luaJS_pushstring(L, context, exception, NULL))
            lua_pushliteral(L, "Unknown JavaScript exception (unable to "
                    "convert thrown exception object into string)");
        return 2;
    }

    if (no_return)
        return 0;

    /* push return value onto lua stack */
    gchar *error = NULL;
    if (luaJS_pushvalue(L, context, result, &error))
        return 1;

    /* handle type conversion errors */
    lua_pushnil(L);
    lua_pushstring(L, error);
    g_free(error);
    return 2;
}
#endif

static gint
luaH_webview_register_function(lua_State *L)
{
#if WITH_WEBKIT2
#else
    WebKitWebFrame *frame = NULL;
#endif
    webview_data_t *d = luaH_checkwvdata(L, 1);
    const gchar *name = luaL_checkstring(L, 2);

    /* get lua callback function */
    luaH_checkfunction(L, 3);
    lua_pushvalue(L, 3);
    gpointer ref = luaH_object_ref(L, -1);

    if (lua_gettop(L) >= 4) {
#if WITH_WEBKIT2
#else
        if (lua_islightuserdata(L, 4))
            frame = lua_touserdata(L, 4);
        else
#endif
        if (lua_isstring(L, 4)) {
#if WITH_WEBKIT2
#else
            if (L_TK_FOCUSED == l_tokenize(lua_tostring(L, 4)))
                frame = webkit_web_view_get_focused_frame(d->view);
#endif
        }
    }

    /* Fall back on main frame */
#if WITH_WEBKIT2
#else
    if (!frame)
        frame = webkit_web_view_get_main_frame(d->view);
#endif

    /* register function */
#if WITH_WEBKIT2
    JSGlobalContextRef context = webkit_web_view_get_javascript_global_context(d->view);
#else
    JSGlobalContextRef context = webkit_web_frame_get_global_context(frame);
#endif
    luaJS_register_function(context, name, ref);
    return 0;
}
#if WITH_WEBKIT2

static void
run_javascript_finished(GObject *obj, GAsyncResult *r, webview_data_t* UNUSED(d))
{
    WebKitJavascriptResult *js_result;
    GError *error = NULL;
    js_result = webkit_web_view_run_javascript_finish(WEBKIT_WEB_VIEW(obj), r, &error);
    if (js_result)
        webkit_javascript_result_unref(js_result);
}
#endif

static gint
luaH_webview_eval_js(lua_State *L)
{
#if WITH_WEBKIT2
#else
    WebKitWebFrame *frame = NULL;
#endif
    webview_data_t *d = luaH_checkwvdata(L, 1);
    const gchar *script = luaL_checkstring(L, 2);
    const gchar *usr_source = NULL;
    gchar *source = NULL;
    bool no_return = false;

    gint top = lua_gettop(L);
    if (top >= 3 && !lua_isnil(L, 3)) {
        luaH_checktable(L, 3);

        /* source filename to use in error messages and webinspector */
        if (luaH_rawfield(L, 3, "source") && lua_isstring(L, -1))
            usr_source = lua_tostring(L, -1);

        if (luaH_rawfield(L, 3, "frame")) {
#if WITH_WEBKIT2
#else
            if (lua_islightuserdata(L, -1))
                frame = lua_touserdata(L, -1);
            else
#endif
            if (lua_isstring(L, -1)) {
#if WITH_WEBKIT2
#else
                if (L_TK_FOCUSED == l_tokenize(lua_tostring(L, -1)))
                    frame = webkit_web_view_get_focused_frame(d->view);
#endif
            }
        }

        if (luaH_rawfield(L, 3, "no_return"))
            no_return = lua_toboolean(L, -1);

        lua_settop(L, top);
    }

    if (!usr_source)
        source = luaH_callerinfo(L);

#if WITH_WEBKIT2
#else
    /* Fall back on main frame */
    if (!frame)
        frame = webkit_web_view_get_main_frame(d->view);
#endif

#if WITH_WEBKIT2
    /* evaluate javascript script */
    luaH_warn(L, "running javascript...");
    webkit_web_view_run_javascript(d->view, script, NULL, (GAsyncReadyCallback) run_javascript_finished, d);
    //JSGlobalContextRef context = webkit_web_view_get_javascript_global_context(d->view);
#else
    /* evaluate javascript script and push return result onto lua stack */
    JSGlobalContextRef context = webkit_web_frame_get_global_context(frame);

    gint ret = luaJS_eval_js(L, context, script,
        usr_source ? usr_source : (const gchar*)source, no_return);
#endif

    g_free(source);

#if WITH_WEBKIT2
    return FALSE;
#else
    return ret;
#endif
}
