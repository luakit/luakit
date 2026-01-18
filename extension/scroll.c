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

#include <jsc/jsc.h>
#include <webkit2/webkit-web-extension.h>

#include "extension/extension.h"
#include "extension/scroll.h"
#include "extension/ipc.h"
#include "extension/luajs.h"

static void
send_scroll_msg(gint h, gint v, WebKitWebPage *web_page, ipc_scroll_subtype_t subtype)
{
    const ipc_scroll_t data = {
        .h = h,
        .v = v,
        .page_id = webkit_web_page_get_id(web_page),
        .subtype = subtype
    };

    ipc_header_t header = {
        .type = IPC_TYPE_scroll,
        .length = sizeof(data)
    };

    ipc_send(extension.ipc, &header, &data);
}

/* Callback data for JavaScript scroll callbacks */
typedef struct {
    WebKitWebPage *web_page;
    ipc_scroll_subtype_t subtype;
} scroll_callback_data_t;

/* Handler called when JavaScript detects scroll event */
static JSCValue *
js_scroll_callback(GPtrArray *args, scroll_callback_data_t *cb_data)
{
    /* JavaScript passes [h, v] as arguments */
    if (args->len >= 2) {
        JSCValue *h_val = g_ptr_array_index(args, 0);
        JSCValue *v_val = g_ptr_array_index(args, 1);

        gint h = jsc_value_to_int32(h_val);
        gint v = jsc_value_to_int32(v_val);

        send_scroll_msg(h, v, cb_data->web_page, cb_data->subtype);
    }

    return jsc_value_new_undefined(jsc_context_get_current());
}

static void
scroll_callback_data_free(scroll_callback_data_t *cb_data)
{
    g_slice_free(scroll_callback_data_t, cb_data);
}

static void
web_page_document_loaded_cb(WebKitWebPage *web_page, gpointer UNUSED(user_data))
{
    /* Get cached JavaScript context (avoids deprecated webkit_web_page_get_main_frame) */
    guint64 page_id = webkit_web_page_get_id(web_page);
    JSCContext *ctx = js_context_cache_get(page_id);
    if (!ctx)
        return;  /* Context not available yet */

    /* Register three JavaScript callbacks for different scroll events */

    /* Callback for window scroll events */
    scroll_callback_data_t *scroll_cb_data = g_slice_new(scroll_callback_data_t);
    scroll_cb_data->web_page = web_page;
    scroll_cb_data->subtype = IPC_SCROLL_TYPE_scroll;

    JSCValue *scroll_func = jsc_value_new_function_variadic(ctx, "luakit_scroll_callback",
                                                             G_CALLBACK(js_scroll_callback),
                                                             scroll_cb_data,
                                                             (GDestroyNotify)scroll_callback_data_free,
                                                             JSC_TYPE_VALUE);
    jsc_context_set_value(ctx, "luakit_scroll_callback", scroll_func);
    g_object_unref(scroll_func);

    /* Callback for window resize events */
    scroll_callback_data_t *resize_cb_data = g_slice_new(scroll_callback_data_t);
    resize_cb_data->web_page = web_page;
    resize_cb_data->subtype = IPC_SCROLL_TYPE_winresize;

    JSCValue *resize_func = jsc_value_new_function_variadic(ctx, "luakit_resize_callback",
                                                             G_CALLBACK(js_scroll_callback),
                                                             resize_cb_data,
                                                             (GDestroyNotify)scroll_callback_data_free,
                                                             JSC_TYPE_VALUE);
    jsc_context_set_value(ctx, "luakit_resize_callback", resize_func);
    g_object_unref(resize_func);

    /* Callback for document resize events */
    scroll_callback_data_t *docresize_cb_data = g_slice_new(scroll_callback_data_t);
    docresize_cb_data->web_page = web_page;
    docresize_cb_data->subtype = IPC_SCROLL_TYPE_docresize;

    JSCValue *docresize_func = jsc_value_new_function_variadic(ctx, "luakit_docresize_callback",
                                                                 G_CALLBACK(js_scroll_callback),
                                                                 docresize_cb_data,
                                                                 (GDestroyNotify)scroll_callback_data_free,
                                                                 JSC_TYPE_VALUE);
    jsc_context_set_value(ctx, "luakit_docresize_callback", docresize_func);
    g_object_unref(docresize_func);

    /* Inject JavaScript to track scroll/resize events */
    const char *js_code =
        "(function() {"
        "    var scrollWidthPrev = -1, scrollHeightPrev = -1;"
        ""
        "    /* Track window scroll events */"
        "    function onScroll() {"
        "        luakit_scroll_callback(window.scrollX, window.scrollY);"
        "    }"
        ""
        "    /* Track window resize events */"
        "    function onResize() {"
        "        luakit_resize_callback(window.innerWidth, window.innerHeight);"
        "    }"
        ""
        "    /* Track document resize events */"
        "    function onDocResize() {"
        "        var html = document.documentElement;"
        "        if (!html) return;"
        "        "
        "        var scrollWidth = html.scrollWidth;"
        "        var scrollHeight = html.scrollHeight;"
        "        "
        "        /* Only send if size actually changed */"
        "        if (scrollWidth !== scrollWidthPrev || scrollHeight !== scrollHeightPrev) {"
        "            scrollWidthPrev = scrollWidth;"
        "            scrollHeightPrev = scrollHeight;"
        "            luakit_docresize_callback(scrollWidth, scrollHeight);"
        "        }"
        "    }"
        ""
        "    /* Add event listeners */"
        "    window.addEventListener('scroll', onScroll);"
        "    window.addEventListener('resize', onResize);"
        "    "
        "    /* DOMSubtreeModified is deprecated but still supported */"
        "    /* Consider using MutationObserver in the future */"
        "    if (document.documentElement) {"
        "        document.documentElement.addEventListener('DOMSubtreeModified', onDocResize);"
        "    }"
        ""
        "    /* Send initial values */"
        "    onScroll();"
        "    onResize();"
        "    onDocResize();"
        "})();";

    JSCValue *result = jsc_context_evaluate(ctx, js_code, -1);
    g_object_unref(result);

    g_object_unref(ctx);
}

static void
web_page_created_cb(WebKitWebExtension *UNUSED(ext), WebKitWebPage *web_page, gpointer UNUSED(user_data))
{
    g_signal_connect(web_page, "document-loaded", G_CALLBACK(web_page_document_loaded_cb), NULL);
}

void
web_scroll_to(guint64 page_id, gint scroll_x, gint scroll_y)
{
    /* Get the WebKitWebPage for IPC messaging */
    WebKitWebPage *page = webkit_web_extension_get_page(extension.ext, page_id);
    if (!page)
        return;

    /* Get cached JavaScript context (avoids deprecated webkit_web_page_get_main_frame) */
    JSCContext *ctx = js_context_cache_get(page_id);
    if (!ctx)
        return;  /* Context not available yet */

    /* Use JavaScript window.scrollTo() instead of WebKitDOM API */
    gchar *js_code = g_strdup_printf("window.scrollTo(%d, %d);", scroll_x, scroll_y);
    JSCValue *result = jsc_context_evaluate(ctx, js_code, -1);
    g_free(js_code);
    g_object_unref(result);

    /* Get new scroll position and send update */
    const char *get_scroll_js = "[window.scrollX, window.scrollY]";
    JSCValue *scroll_result = jsc_context_evaluate(ctx, get_scroll_js, -1);

    if (jsc_value_is_array(scroll_result)) {
        JSCValue *x_val = jsc_value_object_get_property_at_index(scroll_result, 0);
        JSCValue *y_val = jsc_value_object_get_property_at_index(scroll_result, 1);

        gint h = jsc_value_to_int32(x_val);
        gint v = jsc_value_to_int32(y_val);

        send_scroll_msg(h, v, page, IPC_SCROLL_TYPE_scroll);

        g_object_unref(x_val);
        g_object_unref(y_val);
    }

    g_object_unref(scroll_result);
    g_object_unref(ctx);
}

void
web_scroll_init(void)
{
    g_signal_connect(extension.ext, "page-created", G_CALLBACK(web_page_created_cb), NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
