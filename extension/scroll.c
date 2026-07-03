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

#include "extension/extension.h"
#include "extension/scroll.h"
#include "extension/ipc.h"

static void
send_scroll_msg(gint h, gint v, WebKitWebPage *web_page, ipc_scroll_subtype_t subtype)
{
    const ipc_scroll_t data = {
        .h = h, .v = v, .page_id = webkit_web_page_get_id(web_page), .subtype = subtype
    };

    ipc_header_t header = {
        .type = IPC_TYPE_scroll,
        .length = sizeof(data)
    };

    ipc_send(extension.ipc, &header, &data);
}

static void
js_scroll_event_cb(guint64 page_id, gint h, gint v, gint subtype, gpointer UNUSED(user_data))
{
    WebKitWebPage *web_page = webkit_web_process_extension_get_page(extension.ext, page_id);
    g_print("[Extension Debug] js_scroll_event_cb: h=%d, v=%d, subtype=%d\n", h, v, subtype);
    if (web_page) {
        send_scroll_msg(h, v, web_page, (ipc_scroll_subtype_t)subtype);
    }
}

static void
web_page_document_loaded_cb(WebKitWebPage *web_page, gpointer UNUSED(user_data))
{
    guint64 page_id = webkit_web_page_get_id(web_page);
    WebKitFrame *frame = web_page_get_main_frame(web_page);
    if (!frame)
        return;
    JSCContext *ctx = webkit_frame_get_js_context_for_script_world(frame, extension.script_world);
    if (!ctx)
        return;

    JSCValue *func = jsc_value_new_function(ctx, NULL, G_CALLBACK(js_scroll_event_cb), NULL, NULL, G_TYPE_NONE, 4, G_TYPE_UINT64, G_TYPE_INT, G_TYPE_INT, G_TYPE_INT);
    jsc_context_set_value(ctx, "_luakit_scroll_event", func);
    g_object_unref(func);

    const gchar *script =
        "(function(page_id) {\n"
        "    function send(h, v, subtype) {\n"
        "        _luakit_scroll_event(page_id, h, v, subtype);\n"
        "    }\n"
        "    window.addEventListener('scroll', function() {\n"
        "        send(window.scrollX, window.scrollY, 2);\n"
        "    });\n"
        "    window.addEventListener('resize', function() {\n"
        "        send(window.innerWidth, window.innerHeight, 1);\n"
        "    });\n"
        "    var scrollWidthPrev = -1, scrollHeightPrev = -1;\n"
        "    function checkDocResize() {\n"
        "        var html = document.documentElement;\n"
        "        if (!html) return;\n"
        "        var h = html.scrollWidth;\n"
        "        var v = html.scrollHeight;\n"
        "        if (h !== scrollWidthPrev || v !== scrollHeightPrev) {\n"
        "            scrollWidthPrev = h;\n"
        "            scrollHeightPrev = v;\n"
        "            send(h, v, 0);\n"
        "        }\n"
        "    }\n"
        "    if (document.documentElement) {\n"
        "        document.documentElement.addEventListener('DOMSubtreeModified', checkDocResize);\n"
        "    }\n"
        "    send(window.scrollX, window.scrollY, 2);\n"
        "    send(window.innerWidth, window.innerHeight, 1);\n"
        "    checkDocResize();\n"
        "})(%lu);";

    gchar *eval_script = g_strdup_printf(script, (unsigned long)page_id);
    JSCValue *res = jsc_context_evaluate_with_source_uri(ctx, eval_script, -1, NULL, 1);
    if (res)
        g_object_unref(res);
    g_free(eval_script);
    g_object_unref(ctx);
}

static void
web_page_created_cb(WebKitWebProcessExtension *UNUSED(ext), WebKitWebPage *web_page, gpointer UNUSED(user_data))
{
    g_signal_connect(web_page, "document-loaded", G_CALLBACK(web_page_document_loaded_cb), NULL);
}

void
web_scroll_to(guint64 page_id, gint scroll_x, gint scroll_y)
{
    WebKitWebPage *page = webkit_web_process_extension_get_page(extension.ext, page_id);
    g_print("[Extension Debug] web_scroll_to: scroll_x=%d, scroll_y=%d\n", scroll_x, scroll_y);
    if (!page)
        return;
    WebKitFrame *frame = web_page_get_main_frame(page);
    if (!frame)
        return;
    JSCContext *ctx = webkit_frame_get_js_context_for_script_world(frame, extension.script_world);
    if (!ctx)
        return;

    gchar *script = g_strdup_printf("window.scrollTo(%d, %d);", scroll_x, scroll_y);
    JSCValue *res = jsc_context_evaluate_with_source_uri(ctx, script, -1, NULL, 1);
    if (res)
        g_object_unref(res);
    g_free(script);
    g_object_unref(ctx);
}

void
web_scroll_init(void)
{
    g_signal_connect(extension.ext, "page-created", G_CALLBACK(web_page_created_cb), NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
