/*
 * widgets/webview/javascript.c - webkit webview javascript functions
 *
 * Copyright © 2010-2011 Mason Larobina <mason.larobina@gmail.com>
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

static JSValueRef
webview_registered_function_callback(JSContextRef context, JSObjectRef fun,
        JSObjectRef UNUSED(thisObject), size_t UNUSED(argumentCount),
        const JSValueRef* UNUSED(arguments), JSValueRef *exception)
{
    lua_State *L = globalconf.L;
    gpointer ref = JSObjectGetPrivate(fun);
    // get function
    luaH_object_push(L, ref);
    // call function
    gint ret = lua_pcall(L, 0, 0, 0);
    // handle errors
    if (ret != 0) {
        const gchar *exn_cstring = luaL_checkstring(L, -1);
        lua_pop(L, 1);
        JSStringRef exn_js_string = JSStringCreateWithUTF8CString(exn_cstring);
        JSValueRef exn_js_value = JSValueMakeString(context, exn_js_string);
        *exception = JSValueToObject(context, exn_js_value, NULL);
        JSStringRelease(exn_js_string);
    }
    return JSValueMakeUndefined(context);
}

static void
webview_collect_registered_function(JSObjectRef obj)
{
    lua_State *L = globalconf.L;
    gpointer ref = JSObjectGetPrivate(obj);
    luaH_object_unref(L, ref);
}

static void
webview_register_function(WebKitWebFrame *frame, const gchar *name, gpointer ref)
{
    JSGlobalContextRef context = webkit_web_frame_get_global_context(frame);
    JSStringRef js_name = JSStringCreateWithUTF8CString(name);
    // prepare callback function
    JSClassDefinition def = kJSClassDefinitionEmpty;
    def.callAsFunction = webview_registered_function_callback;
    def.className = g_strdup(name);
    def.finalize = webview_collect_registered_function;
    JSClassRef class = JSClassCreate(&def);
    JSObjectRef fun = JSObjectMake(context, class, ref);
    // register with global object
    JSObjectRef global = JSContextGetGlobalObject(context);
    JSObjectSetProperty(context, global, js_name, fun, kJSPropertyAttributeDontDelete | kJSPropertyAttributeReadOnly, NULL);
    // release strings
    JSStringRelease(js_name);
    JSClassRelease(class);
}

static const gchar*
webview_eval_js(WebKitWebFrame *frame, const gchar *script, const gchar *file)
{
    JSGlobalContextRef context;
    JSObjectRef globalobject;
    JSStringRef js_file;
    JSStringRef js_script;
    JSValueRef js_result;
    JSValueRef js_exc = NULL;
    JSStringRef js_result_string;
    GString *result = g_string_new(NULL);
    size_t js_result_size;

    context = webkit_web_frame_get_global_context(frame);
    globalobject = JSContextGetGlobalObject(context);

    /* evaluate the script and get return value*/
    js_script = JSStringCreateWithUTF8CString(script);
    js_file = JSStringCreateWithUTF8CString(file);
    js_result = JSEvaluateScript(context, js_script, globalobject, js_file, 0, &js_exc);
    if (js_result && !JSValueIsUndefined(context, js_result)) {
        js_result_string = JSValueToStringCopy(context, js_result, NULL);
        js_result_size = JSStringGetMaximumUTF8CStringSize(js_result_string);

        if (js_result_size) {
            gchar js_result_utf8[js_result_size];
            JSStringGetUTF8CString(js_result_string, js_result_utf8, js_result_size);
            g_string_assign(result, js_result_utf8);
        }

        JSStringRelease(js_result_string);
    }
    else if (js_exc) {
        size_t size;
        JSStringRef prop, val;
        JSObjectRef exc = JSValueToObject(context, js_exc, NULL);

        g_printf("Exception occured while executing script:\n");

        /* Print file */
        prop = JSStringCreateWithUTF8CString("sourceURL");
        val = JSValueToStringCopy(context, JSObjectGetProperty(context, exc, prop, NULL), NULL);
        size = JSStringGetMaximumUTF8CStringSize(val);
        if(size) {
            gchar cstr[size];
            JSStringGetUTF8CString(val, cstr, size);
            g_printf("At %s", cstr);
        }
        JSStringRelease(prop);
        JSStringRelease(val);

        /* Print line */
        prop = JSStringCreateWithUTF8CString("line");
        val = JSValueToStringCopy(context, JSObjectGetProperty(context, exc, prop, NULL), NULL);
        size = JSStringGetMaximumUTF8CStringSize(val);
        if(size) {
            gchar cstr[size];
            JSStringGetUTF8CString(val, cstr, size);
            g_printf(":%s: ", cstr);
        }
        JSStringRelease(prop);
        JSStringRelease(val);

        /* Print message */
        val = JSValueToStringCopy(context, exc, NULL);
        size = JSStringGetMaximumUTF8CStringSize(val);
        if(size) {
            gchar cstr[size];
            JSStringGetUTF8CString(val, cstr, size);
            g_printf("%s\n", cstr);
        }
        JSStringRelease(val);
    }

    /* cleanup */
    JSStringRelease(js_script);
    JSStringRelease(js_file);

    return g_string_free(result, FALSE);
}

static gint
luaH_webview_register_function(lua_State *L)
{
    WebKitWebFrame *frame = NULL;
    webview_data_t *d = luaH_checkwvdata(L, 1);
    const gchar *name = luaL_checkstring(L, 2);

    /* get lua callback function */
    luaH_checkfunction(L, 3);
    lua_pushvalue(L, 3);
    gpointer ref = luaH_object_ref(L, -1);

    /* Check if function should be registered on currently focused frame */
    if (lua_gettop(L) >= 4 && luaH_checkboolean(L, 4))
        frame = webkit_web_view_get_focused_frame(d->view);

    /* Fall back on main frame */
    if (!frame)
        frame = webkit_web_view_get_main_frame(d->view);

    /* register function */
    webview_register_function(frame, name, ref);
    return 0;
}

static gint
luaH_webview_eval_js(lua_State *L)
{
    WebKitWebFrame *frame = NULL;
    webview_data_t *d = luaH_checkwvdata(L, 1);
    const gchar *script = luaL_checkstring(L, 2);
    const gchar *filename = luaL_checkstring(L, 3);

    /* Check if js should be run on currently focused frame */
    if (lua_gettop(L) >= 4) {
        if (lua_islightuserdata(L, 4))
            frame = lua_touserdata(L, 4);
        else if (lua_toboolean(L, 4))
            frame = webkit_web_view_get_focused_frame(d->view);
    }

    /* Fall back on main frame */
    if (!frame)
        frame = webkit_web_view_get_main_frame(d->view);

    /* evaluate javascript script and push return result onto lua stack */
    const gchar *result = webview_eval_js(frame, script, filename);
    lua_pushstring(L, result);
    return 1;
}
