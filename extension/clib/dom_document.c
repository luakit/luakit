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

#include "extension/extension.h"
#include "extension/clib/dom_document.h"
#include "extension/clib/dom_element.h"
#include "common/tokenize.h"
#include "common/luauniq.h"

#define REG_KEY "luakit.uniq.registry.dom_document"

static lua_class_t dom_document_class;

LUA_OBJECT_FUNCS(dom_document_class, dom_document_t, dom_document);

static guint64
js_value_get_unique_id(JSCValue *val)
{
    JSCContext *ctx = jsc_value_get_context(val);
    JSCValue *js_id = jsc_value_object_get_property(val, "__luakit_id");
    guint64 id;
    if (jsc_value_is_undefined(js_id)) {
        static guint64 next_id = 1;
        id = next_id++;
        JSCValue *new_id = jsc_value_new_number(ctx, id);
        jsc_value_object_set_property(val, "__luakit_id", new_id);
        g_object_unref(new_id);
    } else {
        id = (guint64)jsc_value_to_double(js_id);
    }
    g_object_unref(js_id);
    return id;
}

static dom_document_t*
luaH_check_dom_document(lua_State *L, gint udx)
{
    dom_document_t *document = luaH_checkudata(L, udx, &dom_document_class);
    if (!document->document)
        luaL_argerror(L, udx, "DOM document no longer valid");
    return document;
}

gint
luaH_dom_document_from_webkit_dom_document(lua_State *L, JSCValue *doc)
{
    if (!doc || jsc_value_is_null(doc) || jsc_value_is_undefined(doc)) {
        lua_pushnil(L);
        return 1;
    }

    guint64 id = js_value_get_unique_id(doc);
    void *ptr = (void*)(uintptr_t)id;

    if (luaH_uniq_get_ptr(L, REG_KEY, ptr))
        return 1;

    dom_document_t *document = dom_document_new(L);
    document->document = g_object_ref(doc);

    luaH_uniq_add_ptr(L, REG_KEY, ptr, -1);
    return 1;
}

static gint
luaH_dom_document_gc(lua_State *L)
{
    dom_document_t *document = luaH_toudata(L, 1, &dom_document_class);
    if (document && document->document) {
        guint64 id = js_value_get_unique_id(document->document);
        luaH_uniq_del_ptr(L, REG_KEY, (void*)(uintptr_t)id);
        g_object_unref(document->document);
        document->document = NULL;
    }
    return luaH_object_gc(L);
}

static gint
luaH_dom_document_push_body(lua_State *L, dom_document_t *document)
{
    JSCValue *body = jsc_value_object_get_property(document->document, "body");
    gint ret = luaH_dom_element_from_node(L, body);
    g_object_unref(body);
    return ret;
}

static gint
luaH_dom_document_window_index(lua_State *L)
{
    dom_document_t *document = luaH_check_dom_document(L, lua_upvalueindex(1));
    const gchar *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    JSCContext *ctx = jsc_value_get_context(document->document);
    JSCValue *window = jsc_context_get_value(ctx, "window");

    const gchar *js_prop = NULL;
    switch (token) {
        case L_TK_SCROLL_X: js_prop = "scrollX"; break;
        case L_TK_SCROLL_Y: js_prop = "scrollY"; break;
        case L_TK_INNER_WIDTH: js_prop = "innerWidth"; break;
        case L_TK_INNER_HEIGHT: js_prop = "innerHeight"; break;
        default:
            g_object_unref(window);
            return 0;
    }

    JSCValue *prop_val = jsc_value_object_get_property(window, js_prop);
    double val_num = jsc_value_to_double(prop_val);
    g_object_unref(prop_val);
    g_object_unref(window);

    lua_pushnumber(L, val_num);
    return 1;
}

static gint
luaH_dom_document_push_window_table(lua_State *L)
{
    /* create attribute table */
    lua_newtable(L);
    /* setup metatable */
    lua_createtable(L, 0, 2);
    /* push __index metafunction */
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, 1); /* copy element userdata */
    lua_pushcclosure(L, luaH_dom_document_window_index, 1);
    lua_rawset(L, -3);
    lua_setmetatable(L, -2);
    return 1;
}

static gint
luaH_dom_document_create_element(lua_State *L)
{
    dom_document_t *document = luaH_check_dom_document(L, 1);
    const char *tagname = luaL_checkstring(L, 2);

    JSCContext *ctx = jsc_value_get_context(document->document);
    JSCValue *elem = jsc_value_object_invoke_method(document->document, "createElement", G_TYPE_STRING, tagname, G_TYPE_NONE);

    /* Set all attributes */
    if (lua_istable(L, 3)) {
        lua_pushnil(L);
        while (lua_next(L, 3) != 0) {
            const char *name = luaL_checkstring(L, -2);
            const char *value = luaL_checkstring(L, -1);
            JSCValue *ret = jsc_value_object_invoke_method(elem, "setAttribute", G_TYPE_STRING, name, G_TYPE_STRING, value, G_TYPE_NONE);
            if (ret) g_object_unref(ret);
            lua_pop(L, 1);
        }
    }

    /* Set inner text */
    if (lua_isstring(L, 4)) {
        const char *inner_text = lua_tostring(L, 4);
        JSCValue *inner_val = jsc_value_new_string(ctx, inner_text);
        jsc_value_object_set_property(elem, "innerText", inner_val);
        g_object_unref(inner_val);
    }

    gint ret = luaH_dom_element_from_node(L, elem);
    g_object_unref(elem);
    return ret;
}

static gint
luaH_dom_document_element_from_point(lua_State *L)
{
    dom_document_t *document = luaH_check_dom_document(L, 1);
    glong x = luaL_checknumber(L, 2),
          y = luaL_checknumber(L, 3);

    JSCValue *elem = jsc_value_object_invoke_method(document->document, "elementFromPoint", G_TYPE_INT, x, G_TYPE_INT, y, G_TYPE_NONE);
    gint ret = luaH_dom_element_from_node(L, elem);
    g_object_unref(elem);
    return ret;
}

static gint
luaH_dom_document_index(lua_State *L)
{
    if (luaH_usemetatable(L, 1, 2))
        return 1;

    dom_document_t *document = luaH_check_dom_document(L, 1);
    const char *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    switch(token) {
        PF_CASE(CREATE_ELEMENT, luaH_dom_document_create_element);
        PF_CASE(ELEMENT_FROM_POINT, luaH_dom_document_element_from_point);
        case L_TK_BODY: return luaH_dom_document_push_body(L, document);
        case L_TK_WINDOW: return luaH_dom_document_push_window_table(L);
        default:
            return 0;
    }
}

void
dom_document_class_setup(lua_State *L)
{
    static const struct luaL_Reg dom_document_methods[] =
    {
        LUA_CLASS_METHODS(dom_document)
        { NULL, NULL }
    };

    static const struct luaL_Reg dom_document_meta[] =
    {
        LUA_OBJECT_META(dom_document)
        { "__index", luaH_dom_document_index },
        { "__gc", luaH_dom_document_gc },
        { NULL, NULL }
    };

    luaH_class_setup(L, &dom_document_class, "dom_document",
            (lua_class_allocator_t) dom_document_new,
            NULL, NULL,
            dom_document_methods, dom_document_meta);

    luaH_uniq_setup(L, REG_KEY, "");
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
