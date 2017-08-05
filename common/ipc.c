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

#include <stdlib.h>

#include "common/lualib.h"
#include "common/luaserialize.h"
#include "common/ipc.h"

/* Prototypes for ipc_recv_... functions */
#define X(name) void ipc_recv_##name(ipc_endpoint_t *ipc, const void *msg, guint length);
    IPC_TYPES
#undef X

/*
 * Default process name is "UI" because the UI process currently sends IPC
 * messages before the IPC channel is opened (these messages are queued),
 * and sending IPC messages writes log messages which include the process
 * name.
 */

static GThread *send_thread;
static GAsyncQueue *send_queue;
/** IPC endpoints for all webviews */
static GPtrArray *endpoints;

typedef struct _queued_ipc_t {
    ipc_header_t header;
    ipc_endpoint_t *ipc;
    char payload[0];
} queued_ipc_t;

const GPtrArray *
ipc_endpoints_get(void)
{
    if (!endpoints)
        endpoints = g_ptr_array_sized_new(1);
    return endpoints;
}

static void
ipc_dispatch(ipc_endpoint_t *ipc, ipc_header_t header, gpointer payload)
{
    if (header.type != IPC_TYPE_log)
        debug("Process '%s': recv " ANSI_COLOR_BLUE "%s" ANSI_COLOR_RESET " message",
                ipc->name, ipc_type_name(header.type));
    switch (header.type) {
#define X(name) case IPC_TYPE_##name: ipc_recv_##name(ipc, payload, header.length); break;
        IPC_TYPES
#undef X
        default:
            fatal("Received message with invalid type 0x%x", header.type);
    }
}

static gpointer
ipc_send_thread(gpointer UNUSED(user_data))
{
    while (TRUE) {
        queued_ipc_t *out = g_async_queue_pop(send_queue);
        ipc_endpoint_t *ipc = out->ipc;
        ipc_header_t *header = &out->header;
        gpointer data = out->payload;

        g_io_channel_write_chars(ipc->channel, (gchar*)header, sizeof(*header), NULL, NULL);
        g_io_channel_write_chars(ipc->channel, (gchar*)data, header->length, NULL, NULL);

        /* Message is sent; endpoint can be freed now */
        ipc_endpoint_decref(ipc);
        g_free(out);
    }

    return NULL;
}

void
ipc_send(ipc_endpoint_t *ipc, const ipc_header_t *header, const void *data)
{
    if (!send_thread) {
        send_queue = g_async_queue_new();
        send_thread = g_thread_new("send_thread", ipc_send_thread, NULL);
    }

    /* Keep the endpoint alive while the message is being sent */
    if (!ipc_endpoint_incref(ipc))
        return;

    if (header->type != IPC_TYPE_log)
        debug("Process '%s': send " ANSI_COLOR_BLUE "%s" ANSI_COLOR_RESET " message",
                ipc->name, ipc_type_name(header->type));

    g_assert((header->length == 0) == (data == NULL));

    /* Alloc and push a queued message; the send thread frees it */
    queued_ipc_t *msg = g_malloc(sizeof(*msg) + header->length);
    msg->ipc = ipc;
    msg->header = *header;
    if (header->length)
        memcpy(msg->payload, data, header->length);

    if (ipc->channel)
        g_async_queue_push(send_queue, msg);
    else
        g_queue_push_tail(ipc->queue, msg);
}

static void
ipc_recv_and_dispatch_or_enqueue(ipc_endpoint_t *ipc)
{
    g_assert(ipc);

    ipc_recv_state_t *state = &ipc->recv_state;
    GIOChannel *channel = ipc->channel;

    gchar *buf = (state->hdr_done ? state->payload : &state->hdr) + state->bytes_read;
    gsize remaining = (state->hdr_done ? state->hdr.length : sizeof(state->hdr)) - state->bytes_read;
    gsize bytes_read;
    GError *error = NULL;

    switch (g_io_channel_read_chars(channel, buf, remaining, &bytes_read, &error)) {
        case G_IO_STATUS_NORMAL:
            break;
        case G_IO_STATUS_AGAIN:
            return;
        case G_IO_STATUS_EOF:
            return;
        case G_IO_STATUS_ERROR:
            if (!g_str_equal(ipc->name, "UI"))
            if (!g_str_equal(error->message, "Connection reset by peer"))
                error("g_io_channel_read_chars(): %s", error->message);
            g_error_free(error);
            return;
        default:
            g_assert_not_reached();
    }

    /* Update ipc_recv state */
    state->bytes_read += bytes_read;
    remaining -= bytes_read;

    if (remaining > 0)
        return;

    /* If we've just finished downloading the header... */
    if (!state->hdr_done) {
        /* ... update state, and try to download payload */
        state->hdr_done = TRUE;
        state->bytes_read = 0;
        state->payload = g_malloc(state->hdr.length);
        ipc_recv_and_dispatch_or_enqueue(ipc);
        return;
    }

    /* Otherwise, we finished downloading the message */
    ipc_dispatch(ipc, state->hdr, state->payload);
    g_free(state->payload);

    /* Reset state for the next message */
    state->payload = NULL;
    state->bytes_read = 0;
    state->hdr_done = FALSE;
}

/* Callback function for channel watch */
static gboolean
ipc_recv(GIOChannel *UNUSED(channel), GIOCondition UNUSED(cond), ipc_endpoint_t *ipc)
{
    if (!ipc_endpoint_incref(ipc))
        return TRUE;
    ipc_recv_and_dispatch_or_enqueue(ipc);
    ipc_endpoint_decref(ipc);
    return TRUE;
}

static gboolean
ipc_hup(GIOChannel *UNUSED(channel), GIOCondition UNUSED(cond), ipc_endpoint_t *ipc)
{
    g_assert(ipc->status == IPC_ENDPOINT_CONNECTED);
    g_assert(ipc->channel);
    ipc_endpoint_decref(ipc);
    return TRUE;
}

void
ipc_send_lua(ipc_endpoint_t *ipc, ipc_type_t type, lua_State *L, gint start, gint end)
{
    GByteArray *buf = g_byte_array_new();
    lua_serialize_range(L, buf, start, end);
    ipc_header_t header = { .type = type, .length = buf->len };
    ipc_send(ipc, &header, buf->data);
    g_byte_array_unref(buf);
}

ipc_endpoint_t *
ipc_endpoint_new(const gchar *name)
{
    ipc_endpoint_t *ipc = g_slice_new0(ipc_endpoint_t);

    ipc->name = (gchar*)name;
    ipc->queue = g_queue_new();
    ipc->status = IPC_ENDPOINT_DISCONNECTED;
    ipc->refcount = 1;
    ipc->creation_notified = FALSE;

    return ipc;
}

WARN_UNUSED gboolean
ipc_endpoint_incref(ipc_endpoint_t *ipc)
{
    /* Prevents incref/decref race */
    int old;
    do {
        old = g_atomic_int_get(&ipc->refcount);
        if (old < 1)
            return FALSE;
    } while (!g_atomic_int_compare_and_exchange(&ipc->refcount, old, old+1));
    return TRUE;
}

static void
ipc_endpoint_incref_no_check(ipc_endpoint_t *ipc)
{
    g_atomic_int_inc(&ipc->refcount);
}

void
ipc_endpoint_decref(ipc_endpoint_t *ipc)
{
    if (!g_atomic_int_dec_and_test(&ipc->refcount))
        return;
    if (ipc->status == IPC_ENDPOINT_CONNECTED)
        ipc_endpoint_disconnect(ipc);
    if (ipc->queue) {
        while (!g_queue_is_empty(ipc->queue)) {
            queued_ipc_t *msg = g_queue_pop_head(ipc->queue);
            g_free(msg);
        }
        g_queue_free(ipc->queue);
    }
    ipc->status = IPC_ENDPOINT_FREED;
    g_slice_free(ipc_endpoint_t, ipc);
}

void
ipc_endpoint_connect_to_socket(ipc_endpoint_t *ipc, int sock)
{
    g_assert(ipc);
    g_assert(ipc->status == IPC_ENDPOINT_DISCONNECTED);

    ipc_recv_state_t *state = &ipc->recv_state;
    state->queued_ipcs = g_ptr_array_new();

    GIOChannel *channel = g_io_channel_unix_new(sock);
    g_io_channel_set_encoding(channel, NULL, NULL);
    g_io_channel_set_buffered(channel, FALSE);
    state->watch_in_id = g_io_add_watch(channel, G_IO_IN, (GIOFunc)ipc_recv, ipc);
    state->watch_hup_id = g_io_add_watch(channel, G_IO_HUP, (GIOFunc)ipc_hup, ipc);

    /* Atomically update ipc->channel. This is done because on the web extension
     * thread, logging spawns a message send thread, which may attempt to write
     * to the uninitialized channel after it has been created with
     * g_io_channel_unix_new(), but before it has been set up fully */
    g_atomic_pointer_set(&ipc->channel, channel);

    ipc->status = IPC_ENDPOINT_CONNECTED;

    if (!endpoints)
        endpoints = g_ptr_array_sized_new(1);

    /* Add the endpoint; it should never be present already */
    g_assert(!g_ptr_array_remove_fast(endpoints, ipc));
    g_ptr_array_add(endpoints, ipc);
}

ipc_endpoint_t *
ipc_endpoint_replace(ipc_endpoint_t *orig, ipc_endpoint_t *new)
{
    g_assert(orig);
    g_assert(new);
    g_assert(orig->status == IPC_ENDPOINT_DISCONNECTED);
    g_assert(new->status == IPC_ENDPOINT_CONNECTED);

    /* Incref always succeeds because this is called from a message
     * handler, which holds a temporary ref to the ipc channel  */
    ipc_endpoint_incref_no_check(new);

    /* Send all queued messages */
    if (orig->queue) {
        while (!g_queue_is_empty(orig->queue)) {
            queued_ipc_t *msg = g_queue_pop_head(orig->queue);
            msg->ipc = new;
            ipc_endpoint_incref_no_check(new);
            g_async_queue_push(send_queue, msg);
        }

        g_queue_free(orig->queue);
        orig->queue = NULL;
    }

    ipc_endpoint_decref(orig);
    return new;
}

void
ipc_endpoint_disconnect(ipc_endpoint_t *ipc)
{
    g_assert(ipc->status == IPC_ENDPOINT_CONNECTED);
    g_assert(ipc->channel);

    g_ptr_array_remove_fast(endpoints, ipc);

    /* Remove watches */
    ipc_recv_state_t *state = &ipc->recv_state;
    g_source_remove(state->watch_in_id);
    g_source_remove(state->watch_hup_id);

    /* Close channel */
    g_io_channel_shutdown(ipc->channel, TRUE, NULL);
    ipc->status = IPC_ENDPOINT_DISCONNECTED;
    ipc->channel = NULL;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
