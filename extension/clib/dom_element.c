#include <webkitdom/webkitdom.h>
#define WEBKIT_DOM_USE_UNSTABLE_API
#include <webkitdom/WebKitDOMElementUnstable.h>
#include <webkitdom/WebKitDOMDOMWindowUnstable.h>
#include <webkitdom/WebKitDOMLocation.h>

/* HACK: Normally, I'd include WebKitDOMHTMLMediaElement.h here, and that'd work
 * fine, except that it includes WebKitDOMHTMLElement.h which can only be
 * included from inside webkitdom.h; the problem is, WebKitDOMHTMLMediaElement.h
 * isn't actually included in webkitdom.h, so there's basically no way to get
 * the definitions we need; just copy-paste for now I guess... ugh */
#define WEBKIT_DOM_TYPE_HTML_MEDIA_ELEMENT            (webkit_dom_html_media_element_get_type())
#define WEBKIT_DOM_HTML_MEDIA_ELEMENT(obj)            (G_TYPE_CHECK_INSTANCE_CAST((obj), WEBKIT_DOM_TYPE_HTML_MEDIA_ELEMENT, WebKitDOMHTMLMediaElement))
#define WEBKIT_DOM_IS_HTML_MEDIA_ELEMENT(obj)         (G_TYPE_CHECK_INSTANCE_TYPE((obj), WEBKIT_DOM_TYPE_HTML_MEDIA_ELEMENT))
WEBKIT_API gchar* webkit_dom_html_media_element_get_src(WebKitDOMHTMLMediaElement* self);
WEBKIT_API GType webkit_dom_html_media_element_get_type(void);

#include "extension/clib/dom_element.h"
#include "extension/clib/dom_document.h"
#include "common/luauniq.h"

#define REG_KEY "luakit.uniq.registry.dom_element"

LUA_OBJECT_FUNCS(dom_element_class, dom_element_t, dom_element);

gint
luaH_dom_element_from_node(lua_State *L, WebKitDOMElement* node)
{
    if (luaH_uniq_get_ptr(L, REG_KEY, node))
        return 1;

    lua_newtable(L);
    luaH_class_new(L, &dom_element_class);
    lua_remove(L, -2);

    dom_element_t *element = luaH_checkudata(L, -1, &dom_element_class);
    element->element = WEBKIT_DOM_HTML_ELEMENT(node);

    luaH_uniq_add_ptr(L, REG_KEY, node, -1);

    return 1;
}

static gint
luaH_dom_element_gc(lua_State *L)
{
    return luaH_object_gc(L);
}

static gint
luaH_dom_element_query(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    WebKitDOMElement *elem = WEBKIT_DOM_ELEMENT(element->element);
    const char *query = luaL_checkstring(L, 2);
    GError *error = NULL;

    WebKitDOMNodeList *nodes = webkit_dom_element_query_selector_all(elem, query, &error);

    if (error)
        return luaL_error(L, "query error: %s", error->message);

    gulong n = webkit_dom_node_list_get_length(nodes);

    lua_createtable(L, n, 0);
    for (gulong i=0; i<n; i++) {
        WebKitDOMNode *node = webkit_dom_node_list_item(nodes, i);
        luaH_dom_element_from_node(L, WEBKIT_DOM_ELEMENT(node));
        lua_rawseti(L, 3, i+1);
    }

    return 1;
}

static gint
luaH_dom_element_append(lua_State *L)
{
    dom_element_t *parent = luaH_checkudata(L, 1, &dom_element_class),
                  *child = luaH_checkudata(L, 2, &dom_element_class);
    WebKitDOMNode *p = WEBKIT_DOM_NODE(parent->element),
                  *c = WEBKIT_DOM_NODE(child->element);
    GError *error = NULL;

    webkit_dom_node_append_child(p, c, &error);

    if (error)
        return luaL_error(L, "create element error: %s", error->message);

    return 0;
}

static gint
luaH_dom_element_remove(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    GError *error = NULL;

    webkit_dom_element_remove(WEBKIT_DOM_ELEMENT(element->element), &error);

    if (error)
        return luaL_error(L, "remove element error: %s", error->message);

    return 0;
}

static void
dom_element_get_left_and_top(WebKitDOMElement *elem, glong *l, glong *t)
{
    if (!elem) {
        *l = 0;
        *t = 0;
    } else {
        dom_element_get_left_and_top(webkit_dom_element_get_offset_parent(elem), l, t);
        *l += webkit_dom_element_get_offset_left(elem);
        *l -= webkit_dom_element_get_scroll_left(elem);
        *t += webkit_dom_element_get_offset_top(elem);
        *t -= webkit_dom_element_get_scroll_top(elem);
    }
}

static gint
luaH_dom_element_rect_index(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, lua_upvalueindex(1), &dom_element_class);
    const gchar *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    WebKitDOMElement *elem = WEBKIT_DOM_ELEMENT(element->element);

    glong left, top;

    switch (token) {
        PI_CASE(WIDTH, webkit_dom_element_get_offset_width(elem));
        PI_CASE(HEIGHT, webkit_dom_element_get_offset_height(elem));
        case L_TK_LEFT:
        case L_TK_TOP:
            dom_element_get_left_and_top(elem, &left, &top);
            lua_pushinteger(L, token == L_TK_LEFT ? left : top);
            return 1;
        default:
            return 0;
    }
}

static gint
luaH_dom_element_push_rect_table(lua_State *L)
{
    /* create attribute table */
    lua_newtable(L);
    /* setup metatable */
    lua_createtable(L, 0, 2);
    /* push __index metafunction */
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, 1); /* copy element userdata */
    lua_pushcclosure(L, luaH_dom_element_rect_index, 1);
    lua_rawset(L, -3);
    lua_setmetatable(L, -2);
    return 1;
}

static gint
luaH_dom_element_attribute_index(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, lua_upvalueindex(1), &dom_element_class);
    const gchar *name = luaL_checkstring(L, 2);
    const gchar *attr = webkit_dom_element_get_attribute(WEBKIT_DOM_ELEMENT(element->element), name);
    lua_pushstring(L, attr);
    return 1;
}

static gint
luaH_dom_element_attribute_newindex(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, lua_upvalueindex(1), &dom_element_class);
    const gchar *attr = luaL_checkstring(L, 2);
    const gchar *value = luaL_checkstring(L, 3);
    GError *error = NULL;

    webkit_dom_element_set_attribute(WEBKIT_DOM_ELEMENT(element->element), attr, value, &error);

    if (error)
        return luaL_error(L, "attribute error: %s", error->message);

    return 0;
}

static gint
luaH_dom_element_push_attribute_table(lua_State *L)
{
    /* create attribute table */
    lua_newtable(L);
    /* setup metatable */
    lua_createtable(L, 0, 2);
    /* push __index metafunction */
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, 1); /* copy element userdata */
    lua_pushcclosure(L, luaH_dom_element_attribute_index, 1);
    lua_rawset(L, -3);
    /* push __newindex metafunction */
    lua_pushliteral(L, "__newindex");
    lua_pushvalue(L, 1); /* copy element userdata */
    lua_pushcclosure(L, luaH_dom_element_attribute_newindex, 1);
    lua_rawset(L, -3);
    lua_setmetatable(L, -2);
    return 1;
}

static gint
luaH_dom_element_style_index(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, lua_upvalueindex(1), &dom_element_class);
    WebKitDOMDocument *document = webkit_dom_node_get_owner_document(WEBKIT_DOM_NODE(element->element));
    WebKitDOMDOMWindow *window = webkit_dom_document_get_default_view(document);
    WebKitDOMCSSStyleDeclaration *style = webkit_dom_dom_window_get_computed_style(window, WEBKIT_DOM_ELEMENT(element->element), "");

    const gchar *name = luaL_checkstring(L, 2);
    const gchar *value = webkit_dom_css_style_declaration_get_property_value(style, name);
    lua_pushstring(L, value);
    return 1;
}

static gint
luaH_dom_element_push_style_table(lua_State *L)
{
    /* create style table */
    lua_newtable(L);
    /* setup metatable */
    lua_createtable(L, 0, 2);
    /* push __index metafunction */
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, 1); /* copy element userdata */
    lua_pushcclosure(L, luaH_dom_element_style_index, 1);
    lua_rawset(L, -3);
    lua_setmetatable(L, -2);
    return 1;
}

static gint
luaH_dom_element_click(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    WebKitDOMElement *elem = WEBKIT_DOM_ELEMENT(element->element);
    WebKitDOMDocument *doc = webkit_dom_node_get_owner_document(WEBKIT_DOM_NODE(elem));
    WebKitDOMEventTarget *target = WEBKIT_DOM_EVENT_TARGET(element->element);
    GError *err = NULL;
    WebKitDOMEvent *event = webkit_dom_document_create_event(doc, "MouseEvent", &err);
    if (err)
        return luaL_error(L, "ERROR A: %s\n", err->message);
    webkit_dom_event_init_event(event, "click", TRUE, TRUE);
    webkit_dom_event_target_dispatch_event(target, event, &err);
    if (err)
        return luaL_error(L, "ERROR B: %s\n", err->message);
    /* webkit_dom_html_element_click(WEBKIT_DOM_HTML_ELEMENT(element->element)); */
    return 0;
}

static gint
luaH_dom_element_focus(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    webkit_dom_element_focus(WEBKIT_DOM_ELEMENT(element->element));
    return 0;
}

static gint
luaH_dom_element_submit(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    webkit_dom_html_form_element_submit(WEBKIT_DOM_HTML_FORM_ELEMENT(element->element));
    return 0;
}

static gint
luaH_dom_element_push_src(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);

#define CHECK(lower, upper) \
    if (WEBKIT_DOM_IS_HTML_##upper##_ELEMENT(element->element)) { \
        lua_pushstring(L, webkit_dom_html_##lower##_element_get_src(WEBKIT_DOM_HTML_##upper##_ELEMENT(element->element))); \
        return 1; \
    }

    CHECK(input, INPUT);
    CHECK(frame, FRAME);
    CHECK(media, MEDIA);
    CHECK(iframe, IFRAME);
    CHECK(embed, EMBED);
    CHECK(image, IMAGE);
    CHECK(script, SCRIPT);

#undef CHECK

    return 0;
}

static gint
luaH_dom_element_push_href(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);

#define CHECK(lower, upper) \
    if (WEBKIT_DOM_IS_##upper(element->element)) { \
        lua_pushstring(L, webkit_dom_##lower##_get_href(WEBKIT_DOM_##upper(element->element))); \
        return 1; \
    }

    CHECK(location, LOCATION);
    CHECK(html_anchor_element, HTML_ANCHOR_ELEMENT);
    CHECK(html_area_element, HTML_AREA_ELEMENT);
    CHECK(html_link_element, HTML_LINK_ELEMENT);
    CHECK(style_sheet, STYLE_SHEET);

#undef CHECK

    return 0;
}

static gint
luaH_dom_element_push_value(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);

#define CHECK(lower, upper, type) \
    if (WEBKIT_DOM_IS_HTML_##upper##_ELEMENT(element->element)) { \
        lua_push##type(L, webkit_dom_html_##lower##_element_get_value( \
                    WEBKIT_DOM_HTML_##upper##_ELEMENT(element->element))); \
        return 1; \
    }

    CHECK(text_area, TEXT_AREA, string);
    CHECK(input, INPUT, string);
    CHECK(option, OPTION, string);
    CHECK(param, PARAM, string);
    CHECK(li, LI, integer);
    CHECK(button, BUTTON, string);
    CHECK(select, SELECT, string);

#undef CHECK

    return 0;
}

static gint
dom_html_element_set_value(lua_State *L, WebKitDOMHTMLElement *element)
{

#define CHECK(lower, upper, type) \
    if (WEBKIT_DOM_IS_HTML_##upper##_ELEMENT(element)) { \
        webkit_dom_html_##lower##_element_set_value( \
                WEBKIT_DOM_HTML_##upper##_ELEMENT(element), \
                luaL_check##type(L, 3)); \
        return 1; \
    }

    CHECK(text_area, TEXT_AREA, string);
    CHECK(input, INPUT, string);
    CHECK(option, OPTION, string);
    CHECK(param, PARAM, string);
    CHECK(li, LI, integer);
    CHECK(button, BUTTON, string);
    CHECK(select, SELECT, string);

#undef CHECK

    return 0;
}

static gint
luaH_dom_element_push_parent(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    WebKitDOMNode *parent = webkit_dom_node_get_parent_node(WEBKIT_DOM_NODE(element->element));
    return luaH_dom_element_from_node(L, WEBKIT_DOM_ELEMENT(parent));
}

static gint
luaH_dom_element_push_first_child(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    WebKitDOMElement *elem = WEBKIT_DOM_ELEMENT(element->element);
    WebKitDOMElement *child = webkit_dom_element_get_first_element_child(elem);
    return luaH_dom_element_from_node(L, child);
}

static gint
luaH_dom_element_push_last_child(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    WebKitDOMElement *elem = WEBKIT_DOM_ELEMENT(element->element);
    WebKitDOMElement *child = webkit_dom_element_get_last_element_child(elem);
    return luaH_dom_element_from_node(L, child);
}

static gint
luaH_dom_element_push_prev_sibling(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    WebKitDOMElement *elem = WEBKIT_DOM_ELEMENT(element->element);
    WebKitDOMElement *child = webkit_dom_element_get_previous_element_sibling(elem);
    return luaH_dom_element_from_node(L, child);
}

static gint
luaH_dom_element_push_next_sibling(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    WebKitDOMElement *elem = WEBKIT_DOM_ELEMENT(element->element);
    WebKitDOMElement *child = webkit_dom_element_get_next_element_sibling(elem);
    return luaH_dom_element_from_node(L, child);
}

static gint
luaH_dom_element_push_document(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    WebKitDOMDocument *doc;

    if (WEBKIT_DOM_IS_HTML_FRAME_ELEMENT(element->element)) {
        doc = webkit_dom_html_frame_element_get_content_document(
                WEBKIT_DOM_HTML_FRAME_ELEMENT(element->element));
    } else if (WEBKIT_DOM_IS_HTML_IFRAME_ELEMENT(element->element)) {
        doc = webkit_dom_html_iframe_element_get_content_document(
                WEBKIT_DOM_HTML_IFRAME_ELEMENT(element->element));
    } else
        return 0;

    return luaH_dom_document_from_webkit_dom_document(L, doc);
}

static gint
luaH_dom_element_push_owner_document(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    WebKitDOMDocument *doc = webkit_dom_node_get_owner_document(WEBKIT_DOM_NODE(element->element));
    return luaH_dom_document_from_webkit_dom_document(L, doc);
}

static gint
luaH_dom_element_index(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    const char *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    WebKitDOMElement *elem = WEBKIT_DOM_ELEMENT(element->element);

    switch(token) {
        PS_CASE(TAG_NAME, webkit_dom_element_get_tag_name(elem))
        PS_CASE(TEXT_CONTENT, webkit_dom_node_get_text_content(WEBKIT_DOM_NODE(elem)))
        PS_CASE(INNER_HTML, webkit_dom_element_get_inner_html(elem))

        PF_CASE(QUERY, luaH_dom_element_query)
        PF_CASE(APPEND, luaH_dom_element_append)
        PF_CASE(REMOVE, luaH_dom_element_remove)
        PF_CASE(CLICK, luaH_dom_element_click)
        PF_CASE(FOCUS, luaH_dom_element_focus)
        PF_CASE(SUBMIT, luaH_dom_element_submit)

        PI_CASE(CHILD_COUNT, webkit_dom_element_get_child_element_count(elem))

        case L_TK_SRC: return luaH_dom_element_push_src(L);
        case L_TK_HREF: return luaH_dom_element_push_href(L);
        case L_TK_VALUE: return luaH_dom_element_push_value(L);
        case L_TK_CHECKED: return webkit_dom_html_input_element_get_checked(
                                   WEBKIT_DOM_HTML_INPUT_ELEMENT(elem));
        case L_TK_TYPE: {
            gchar *type;
            g_object_get(element->element, "type", &type, NULL);
            lua_pushstring(L, type);
            return 1;
        }
        case L_TK_PARENT: return luaH_dom_element_push_parent(L);
        case L_TK_FIRST_CHILD: return luaH_dom_element_push_first_child(L);
        case L_TK_LAST_CHILD: return luaH_dom_element_push_last_child(L);
        case L_TK_PREV_SIBLING: return luaH_dom_element_push_prev_sibling(L);
        case L_TK_NEXT_SIBLING: return luaH_dom_element_push_next_sibling(L);
        case L_TK_RECT: return luaH_dom_element_push_rect_table(L);
        case L_TK_ATTR: return luaH_dom_element_push_attribute_table(L);
        case L_TK_STYLE: return luaH_dom_element_push_style_table(L);
        case L_TK_DOCUMENT: return luaH_dom_element_push_document(L);
        case L_TK_OWNER_DOCUMENT: return luaH_dom_element_push_owner_document(L);
        default:
            return 0;
    }
}

static gint
luaH_dom_element_newindex(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    const char *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    GError *error = NULL;

    switch (token) {
        case L_TK_INNER_HTML:
            webkit_dom_element_set_inner_html(WEBKIT_DOM_ELEMENT(element->element),
                    luaL_checkstring(L, 3), &error);
            if (error)
                return luaL_error(L, "set inner html error: %s", error->message);
        case L_TK_VALUE:
            if (!dom_html_element_set_value(L, element->element))
                return luaL_error(L, "set value error: wrong element type");
        case L_TK_CHECKED:
            webkit_dom_html_input_element_set_checked(
                    WEBKIT_DOM_HTML_INPUT_ELEMENT(element->element),
                    lua_toboolean(L, 3));
            return 0;
        default:
            break;
    }

    return 0;
}

void
dom_element_class_setup(lua_State *L)
{
    static const struct luaL_reg dom_element_methods[] =
    {
        LUA_CLASS_METHODS(dom_element)
        { NULL, NULL }
    };

    static const struct luaL_reg dom_element_meta[] =
    {
        LUA_OBJECT_META(dom_element)
        { "__index", luaH_dom_element_index },
        { "__newindex", luaH_dom_element_newindex },
        { "__gc", luaH_dom_element_gc },
        { NULL, NULL }
    };

    luaH_class_setup(L, &dom_element_class, "dom_element",
            (lua_class_allocator_t) dom_element_new,
            NULL, NULL,
            dom_element_methods, dom_element_meta);

    luaH_uniq_setup(L, REG_KEY);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
