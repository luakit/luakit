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

#define WEBKIT_DOM_USE_UNSTABLE_API
#include <webkitdom/WebKitDOMDOMWindowUnstable.h>

#include "extension/extension.h"
#include "extension/scroll.h"
#include "extension/ipc.h"

static void
send_scroll_msg(gint h, gint v, WebKitWebPage *web_page, ipc_scroll_subtype_t subtype)
{
    const ipc_scroll_t data = {
        .h = h, .v = v,.page_id = webkit_web_page_get_id(web_page), .subtype = subtype
    };

    ipc_header_t header = {
        .type = IPC_TYPE_scroll,
        .length = sizeof(data)
    };

    ipc_send(extension.ipc, &header, &data);
}

static void
window_scroll_cb(WebKitDOMDOMWindow *window, WebKitDOMEvent *UNUSED(event), WebKitWebPage *web_page)
{
    gint h = webkit_dom_dom_window_get_scroll_x(window);
    gint v = webkit_dom_dom_window_get_scroll_y(window);
    send_scroll_msg(h, v, web_page, IPC_SCROLL_TYPE_scroll);
}

static void
window_resize_cb(WebKitDOMDOMWindow *window, WebKitDOMEvent *UNUSED(event), WebKitWebPage *web_page)
{
    gint h = webkit_dom_dom_window_get_inner_width(window);
    gint v = webkit_dom_dom_window_get_inner_height(window);
    send_scroll_msg(h, v, web_page, IPC_SCROLL_TYPE_winresize);
}

static gint scroll_width_prev = -1, scroll_height_prev = -1;

static void
document_resize_cb(WebKitDOMElement *html, WebKitDOMEvent *UNUSED(event), WebKitWebPage *web_page)
{
    gint h = webkit_dom_element_get_scroll_width(html);
    gint v = webkit_dom_element_get_scroll_height(html);

    /* Only send message if the size changes */
    /* This still isn't that performant... needs a better solution really */
    if (h == scroll_width_prev && v == scroll_height_prev)
        return;
    scroll_width_prev = h;
    scroll_height_prev = v;

    send_scroll_msg(h, v, web_page, IPC_SCROLL_TYPE_docresize);
}

static void
web_page_document_loaded_cb(WebKitWebPage *web_page, gpointer UNUSED(user_data))
{
    WebKitDOMDocument *document = webkit_web_page_get_dom_document(web_page);
    WebKitDOMElement *html = webkit_dom_document_get_document_element(document);
    WebKitDOMDOMWindow *window = webkit_dom_document_get_default_view(document);

    /* Add event listeners... */

    webkit_dom_event_target_add_event_listener(WEBKIT_DOM_EVENT_TARGET(window),
        "scroll", G_CALLBACK(window_scroll_cb), FALSE, web_page);
    webkit_dom_event_target_add_event_listener(WEBKIT_DOM_EVENT_TARGET(window),
        "resize", G_CALLBACK(window_resize_cb), FALSE, web_page);
    webkit_dom_event_target_add_event_listener(WEBKIT_DOM_EVENT_TARGET(html),
        "DOMSubtreeModified", G_CALLBACK(document_resize_cb), FALSE, web_page);

    /* ... and make sure initial values are set */

    window_scroll_cb(window, NULL, web_page);
    window_resize_cb(window, NULL, web_page);
    document_resize_cb(html, NULL, web_page);
}

static void
web_page_created_cb(WebKitWebExtension *UNUSED(ext), WebKitWebPage *web_page, gpointer UNUSED(user_data))
{
    g_signal_connect(web_page, "document-loaded", G_CALLBACK(web_page_document_loaded_cb), NULL);
}

void
web_scroll_to(guint64 page_id, gint scroll_x, gint scroll_y)
{
    WebKitWebPage *page = webkit_web_extension_get_page(extension.ext, page_id);
    WebKitDOMDocument *document = webkit_web_page_get_dom_document(page);
    WebKitDOMDOMWindow *window = webkit_dom_document_get_default_view(document);

    /* Scroll, then tell UI process what the new scroll position is */
    webkit_dom_dom_window_scroll_to(window, scroll_x, scroll_y);
    window_scroll_cb(window, NULL, page);
}

void
web_scroll_init(void)
{
    g_signal_connect(extension.ext, "page-created", G_CALLBACK(web_page_created_cb), NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
