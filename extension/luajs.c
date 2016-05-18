#include <JavaScriptCore/JavaScript.h>
#include <unistd.h>

#define LUAKIT_LUAJS_REGISTRY_KEY "luakit.luajs.registry"

#include "extension/extension.h"
#include "common/msg.h"
#include "common/lualib.h"
#include "common/luaserialize.h"

static void register_func(WebKitScriptWorld *world, WebKitFrame *frame, const gchar *name, gpointer ref);

static JSValueRef
luaJS_tovalue(lua_State *L, JSContextRef context, gint idx, gchar **error);

static gint
luaJS_pushvalue(lua_State *L, JSContextRef context, JSValueRef value, gchar **error);

static void
lua_gc_stack_top(lua_State *L)
{
    GByteArray *buf = g_byte_array_new();
    lua_serialize_range(L, buf, -1, -1);
    msg_header_t header = {
        .type = MSG_TYPE_lua_js_gc,
        .length = buf->len
    };
    msg_send(&header, buf->data);
    g_byte_array_unref(buf);
}

static gchar*
tostring(JSContextRef context, JSValueRef value, gchar **error)
{
    JSStringRef str = JSValueToStringCopy(context, value, NULL);
    if (!str) {
        if (error)
            *error = g_strdup("string conversion failed");
        return NULL;
    }
    size_t size = JSStringGetMaximumUTF8CStringSize(str);
    gchar *ret = g_malloc(sizeof(gchar)*size);
    JSStringGetUTF8CString(str, ret, size);
    JSStringRelease(str);
    return ret;
}

static gint
luaJS_pushstring(lua_State *L, JSContextRef context, JSValueRef value, gchar **error)
{
    gchar *str = tostring(context, value, error);
    if (str) {
        lua_pushstring(L, str);
        g_free(str);
        return 1;
    }
    return 0;
}

static gint
luaJS_pushobject(lua_State *L, JSContextRef context, JSObjectRef obj, gchar **error)
{
    gint top = lua_gettop(L);

    JSPropertyNameArrayRef keys = JSObjectCopyPropertyNames(context, obj);
    size_t count = JSPropertyNameArrayGetCount(keys);
    JSValueRef exception = NULL;

    lua_newtable(L);

    for (size_t i = 0; i < count; i++) {
        /* push table key onto stack */
        JSStringRef key = JSPropertyNameArrayGetNameAtIndex(keys, i);
        size_t slen = JSStringGetMaximumUTF8CStringSize(key);
        gchar cstr[slen];
        JSStringGetUTF8CString(key, cstr, slen);

        gchar *eptr = NULL;
        int n = strtol(cstr, &eptr, 10);
        if (!*eptr) /* end at '\0' ? == it's a number! */
            lua_pushinteger(L, ++n); /* 0-index array to 1-index array */
        else
            lua_pushstring(L, cstr);

        /* push table value into stack */
        JSValueRef val = JSObjectGetProperty(context, obj, key, &exception);
        if (exception) {
            lua_settop(L, top);
            if (error) {
                gchar *err = tostring(context, exception, NULL);
                *error = g_strdup_printf("JSObjectGetProperty call failed (%s)",
                        err ? err : "unknown reason");
                g_free(err);
            }
            JSPropertyNameArrayRelease(keys);
            return 0;
        }
        luaJS_pushvalue(L, context, val, error);
        if (error && *error) {
            lua_settop(L, top);
            JSPropertyNameArrayRelease(keys);
            return 0;
        }
        lua_rawset(L, -3);
    }
    JSPropertyNameArrayRelease(keys);
    return 1;
}

/* Push JavaScript value onto Lua stack */
static gint
luaJS_pushvalue(lua_State *L, JSContextRef context, JSValueRef value, gchar **error)
{
    switch (JSValueGetType(context, value)) {
      case kJSTypeBoolean:
        lua_pushboolean(L, JSValueToBoolean(context, value));
        return 1;

      case kJSTypeNumber:
        lua_pushnumber(L, JSValueToNumber(context, value, NULL));
        return 1;

      case kJSTypeString:
        return luaJS_pushstring(L, context, value, error);

      case kJSTypeObject:
        return luaJS_pushobject(L, context, (JSObjectRef)value, error);

      case kJSTypeUndefined:
      case kJSTypeNull:
        lua_pushnil(L);
        return 1;

      default:
        break;
    }
    if (error)
        *error = g_strdup("Unable to convert value into equivalent Lua type");
    return 0;
}

static JSValueRef
luaJS_fromtable(lua_State *L, JSContextRef context, gint idx, gchar **error)
{
    gint top = lua_gettop(L);

    /* convert relative index into abs */
    if (idx < 0)
        idx = top + idx + 1;

    JSValueRef exception = NULL;
    JSObjectRef obj;

    size_t len = lua_objlen(L, idx);
    if (len) {
        obj = JSObjectMakeArray(context, 0, NULL, &exception);
        if (exception) {
            if (error) {
                gchar *err = tostring(context, exception, NULL);
                *error = g_strdup_printf("JSObjectMakeArray call failed (%s)",
                        err ? err : "unknown reason");
                g_free(err);
            }
            return NULL;
        }

        lua_pushnil(L);
        for (guint i = 0; lua_next(L, idx); i++) {
            JSValueRef val = luaJS_tovalue(L, context, -1, error);
            if (error && *error) {
                lua_settop(L, top);
                return NULL;
            }
            lua_pop(L, 1);
            JSObjectSetPropertyAtIndex(context, obj, i, val, &exception);
        }
    } else {
        obj = JSObjectMake(context, NULL, NULL);
        lua_pushnil(L);
        while (lua_next(L, idx)) {
            /* We only care about string attributes in the table */
            if (lua_type(L, -2) == LUA_TSTRING) {
                JSValueRef val = luaJS_tovalue(L, context, -1, error);
                if (error && *error) {
                    lua_settop(L, top);
                    return NULL;
                }
                JSStringRef key = JSStringCreateWithUTF8CString(lua_tostring(L, -2));
                JSObjectSetProperty(context, obj, key, val,
                        kJSPropertyAttributeNone, &exception);
                JSStringRelease(key);
                if (exception) {
                    if (error) {
                        gchar *err = tostring(context, exception, NULL);
                        *error = g_strdup_printf("JSObjectSetProperty call failed (%s)",
                                err ? err : "unknown reason");
                        g_free(err);
                    }
                    return NULL;
                }
            }
            lua_pop(L, 1);
        }
    }
    return obj;
}

/* Make JavaScript value from Lua value */
static JSValueRef
luaJS_tovalue(lua_State *L, JSContextRef context, gint idx, gchar **error)
{
    JSStringRef str;
    JSValueRef ret;

    switch (lua_type(L, idx)) {
      case LUA_TBOOLEAN:
        return JSValueMakeBoolean(context, lua_toboolean(L, idx));

      case LUA_TNUMBER:
        return JSValueMakeNumber(context, lua_tonumber(L, idx));

      case LUA_TNIL:
        return JSValueMakeNull(context);

      case LUA_TNONE:
        return JSValueMakeUndefined(context);

      case LUA_TSTRING:
        str = JSStringCreateWithUTF8CString(lua_tostring(L, idx));
        ret = JSValueMakeString(context, str);
        JSStringRelease(str);
        return ret;

      case LUA_TTABLE:
        return luaJS_fromtable(L, context, idx, error);

      default:
        break;
    }

    if (error)
        *error = g_strdup_printf("unhandled Lua->JS type conversion (type %s)",
                lua_typename(L, lua_type(L, idx)));
    return JSValueMakeUndefined(context);
}

/* create JavaScript exception object from string */
static JSValueRef
luaJS_make_exception(JSContextRef context, const gchar *error)
{
    JSStringRef estr = JSStringCreateWithUTF8CString(error);
    JSValueRef exception = JSValueMakeString(context, estr);
    JSStringRelease(estr);
    return JSValueToObject(context, exception, NULL);
}


static JSValueRef
luaJS_registered_function_callback(JSContextRef context, JSObjectRef fun,
        JSObjectRef UNUSED(this), size_t argc, const JSValueRef *argv,
        JSValueRef *exception)
{
    lua_State *L = extension.WL;
    gint top = lua_gettop(L);

    /* Push function ref onto Lua stack */
    lua_pushlightuserdata(L, JSObjectGetPrivate(fun));

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

    /* Notify UI process of function call... */

    GByteArray *buf = g_byte_array_new();
    lua_serialize_range(L, buf, top + 1, lua_gettop(L));

    msg_header_t header = {
        .type = MSG_TYPE_lua_js_call,
        .length = buf->len
    };

    msg_send(&header, buf->data);
    g_byte_array_unref(buf);

    /* ...and block until it's replied */

    do {
        usleep(1);
    } while(!msg_recv_and_dispatch_or_enqueue(MSG_TYPE_lua_js_call));

    /* At this point, reply was just handled in msg_recv_lua_js_call() below */

    JSValueRef ret;

    if (lua_toboolean(L, -1))
        error = luaL_checkstring(L, -2);
    else
        ret = luaJS_tovalue(L, context, -2, &error);

    /* invalid return type from registered function */
    if (error) {
        *exception = luaJS_make_exception(context, error);
        ret = JSValueMakeUndefined(context);
    }

    lua_settop(L, top);
    return ret;
}

void
msg_recv_lua_js_call(const guint8 *msg, guint length)
{
    lua_State *L = extension.WL;
    int n = lua_deserialize_range(L, msg, length);
    /* Should have two values: arbitrary return value, and ok/err status */
    g_assert_cmpint(n, ==, 2);
    g_assert(lua_isboolean(L, -1));
}

void
msg_recv_lua_js_register(const guint8 *msg, guint length)
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
    lua_State *L = extension.WL;
    lua_pushlightuserdata(L, obj);
    lua_gc_stack_top(L);
    lua_pop(L, 1);
}

static void register_func(WebKitScriptWorld *world, WebKitFrame *frame, const gchar *name, gpointer ref)
{
    JSGlobalContextRef context = webkit_frame_get_javascript_context_for_script_world(frame, world);

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

static void
window_object_cleared_cb(WebKitScriptWorld *world, WebKitWebPage *web_page, WebKitFrame *frame, gpointer user_data)
{
    lua_State *L = extension.WL;
    const gchar *uri = webkit_web_page_get_uri(web_page);

    /* Push string.find() */
    lua_getglobal(L, "string");
    lua_getfield(L, -1, "find");
    lua_replace(L, -2);

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
        lua_pushvalue(L, -4);
        lua_pushstring(L, uri);
        lua_pushvalue(L, -4);
        lua_pcall(L, 2, 1, 0);

        if (!lua_isnil(L, -1)) {
            /* got a match: iterate over all functions */
            lua_pushnil(L);
            while (lua_next(L, -3) != 0) {
                /* Entries must be name -> ref */
                g_assert(lua_isstring(L, -2));
                g_assert(lua_islightuserdata(L, -1));
                /* Register the function */
                register_func(world, frame, lua_tostring(L, -2), lua_topointer(L, -1));
                lua_pop(L, 1);
            }
        }

        /* Pop off return code and the function value */
        lua_pop(L, 2);
    }

    /* Pop off table and string.find() */
    lua_pop(L, 2);
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
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
