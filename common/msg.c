#include <stdlib.h>

#include "common/lualib.h"
#include "common/luaserialize.h"
#include "common/msg.h"

/* Prototypes for msg_recv_... functions */
#define X(name) void msg_recv_##name(msg_endpoint_t *ipc, const void *msg, guint length);
    MSG_TYPES
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

typedef struct _queued_msg_t {
    msg_header_t header;
    msg_endpoint_t *ipc;
    char payload[0];
} queued_msg_t;

const GPtrArray *
msg_endpoints_get(void)
{
    return endpoints;
}

static void
msg_dispatch(msg_endpoint_t *ipc, msg_header_t header, gpointer payload)
{
    if (header.type != MSG_TYPE_log)
        debug("Process '%s': recv " ANSI_COLOR_BLUE "%s" ANSI_COLOR_RESET " message",
                ipc->name, msg_type_name(header.type));
    switch (header.type) {
#define X(name) case MSG_TYPE_##name: msg_recv_##name(ipc, payload, header.length); break;
        MSG_TYPES
#undef X
        default:
            fatal("Received message with invalid type 0x%x", header.type);
    }
}

static gboolean
msg_dispatch_enqueued(msg_endpoint_t *ipc)
{
    msg_recv_state_t *state = &ipc->recv_state;

    if (state->queued_msgs->len > 0) {
        queued_msg_t *msg = g_ptr_array_index(state->queued_msgs, 0);
        /* Dispatch and free the message */
        msg_dispatch(msg->ipc, msg->header, msg->payload);
        g_ptr_array_remove_index(state->queued_msgs, 0);
        g_slice_free1(sizeof(queued_msg_t) + state->hdr.length, state->payload);
        return TRUE;
    }
    return FALSE;
}

static gpointer
msg_send_thread(gpointer UNUSED(user_data))
{
    while (TRUE) {
        queued_msg_t *out = g_async_queue_pop(send_queue);
        msg_endpoint_t *ipc = out->ipc;
        msg_header_t *header = &out->header;
        gpointer data = out->payload;

        if (ipc->channel) {
            g_io_channel_write_chars(ipc->channel, (gchar*)header, sizeof(*header), NULL, NULL);
            g_io_channel_write_chars(ipc->channel, (gchar*)data, header->length, NULL, NULL);
        } else {
            g_byte_array_append(ipc->queue, (guint8*)header, sizeof(*header));
            g_byte_array_append(ipc->queue, (guint8*)data, header->length);
        }

        /* Message is sent; endpoint can be freed now */
        msg_endpoint_decref(ipc);
        g_free(out);
    }

    return NULL;
}

void
msg_send(msg_endpoint_t *ipc, const msg_header_t *header, const void *data)
{
    if (!send_thread) {
        send_queue = g_async_queue_new();
        send_thread = g_thread_new("send_thread", msg_send_thread, NULL);
    }

    if (header->type != MSG_TYPE_log)
        debug("Process '%s': send " ANSI_COLOR_BLUE "%s" ANSI_COLOR_RESET " message",
                ipc->name, msg_type_name(header->type));

    g_assert(ipc);
    /* Keep the endpoint alive while the message is being sent */
    msg_endpoint_incref(ipc);
    g_assert((header->length == 0) == (data == NULL));

    /* Alloc and push a queued message; the send thread frees it */
    queued_msg_t *msg = g_malloc(sizeof(*msg) + header->length);
    msg->ipc = ipc;
    msg->header = *header;
    if (header->length)
        memcpy(msg->payload, data, header->length);
    g_async_queue_push(send_queue, msg);
}

/* Callback function for channel watch */
static gboolean
msg_recv(GIOChannel *UNUSED(channel), GIOCondition cond, msg_endpoint_t *ipc)
{
    g_assert(cond & G_IO_IN);

    (void) (msg_dispatch_enqueued(ipc) || msg_recv_and_dispatch_or_enqueue(ipc, MSG_TYPE_ANY));

    return TRUE;
}

static gboolean
msg_hup(GIOChannel *UNUSED(channel), GIOCondition UNUSED(cond), msg_endpoint_t *ipc)
{
    g_assert(ipc->status == MSG_ENDPOINT_CONNECTED);
    g_assert(ipc->channel);

    g_ptr_array_remove_fast(endpoints, ipc);
    msg_endpoint_disconnect(ipc);
    msg_endpoint_decref(ipc);
    if (!strcmp(ipc->name, "Web"))
        exit(0);
    return FALSE;
}

/* Receive a single message
 * If the message matches the type mask, dispatch it; otherwise, enqueue it
 * Return true if a message was dispatched */
gboolean
msg_recv_and_dispatch_or_enqueue(msg_endpoint_t *ipc, int type_mask)
{
    g_assert(ipc);
    g_assert(type_mask != 0);

    msg_recv_state_t *state = &ipc->recv_state;
    GIOChannel *channel = ipc->channel;

    gchar *buf = (state->hdr_done ? state->payload+sizeof(queued_msg_t) : &state->hdr) + state->bytes_read;
    gsize remaining = (state->hdr_done ? state->hdr.length : sizeof(state->hdr)) - state->bytes_read;
    gsize bytes_read;
    GError *error = NULL;
    GIOStatus s;

    switch ((s = g_io_channel_read_chars(channel, buf, remaining, &bytes_read, &error))) {
        case G_IO_STATUS_NORMAL:
        case G_IO_STATUS_AGAIN:
            break;
        default:
            /* TODO: error */
            break;
    }

    /* Update msg_recv state */
    state->bytes_read += bytes_read;
    remaining -= bytes_read;

    if (remaining > 0)
        return FALSE;

    /* If we've just finished downloading the header... */
    if (!state->hdr_done) {
        /* ... update state, and try to download payload */
        state->hdr_done = TRUE;
        state->bytes_read = 0;
        state->payload = g_slice_alloc(sizeof(queued_msg_t) + state->hdr.length);
        return msg_recv_and_dispatch_or_enqueue(ipc, type_mask);
    }

    /* Otherwise, we finished downloading the message */
    if (state->hdr.type & type_mask) {
        msg_dispatch(ipc, state->hdr, state->payload+sizeof(queued_msg_t));
        g_slice_free1(sizeof(queued_msg_t) + state->hdr.length, state->payload);
    } else {
        /* Copy the header into the space at the start of the payload slice */
        queued_msg_t *queued_msg = state->payload;
        queued_msg->header = state->hdr;
        queued_msg->ipc = ipc;
        g_ptr_array_add(state->queued_msgs, state->payload);
        g_idle_add((GSourceFunc)msg_dispatch_enqueued, ipc);
    }

    /* Reset state for the next message */
    state->payload = NULL;
    state->bytes_read = 0;
    state->hdr_done = FALSE;

    /* Return true if we dispatched it */
    return state->hdr.type & type_mask;
}

void
msg_send_lua(msg_endpoint_t *ipc, msg_type_t type, lua_State *L, gint start, gint end)
{
    GByteArray *buf = g_byte_array_new();
    lua_serialize_range(L, buf, start, end);
    msg_header_t header = { .type = type, .length = buf->len };
    msg_send(ipc, &header, buf->data);
    g_byte_array_unref(buf);
}

msg_endpoint_t *
msg_endpoint_new(const gchar *name)
{
    msg_endpoint_t *ipc = g_slice_new0(msg_endpoint_t);

    ipc->name = (gchar*)name;
    ipc->queue = g_byte_array_new();
    ipc->status = MSG_ENDPOINT_DISCONNECTED;
    ipc->refcount = 1;

    return ipc;
}

void
msg_endpoint_incref(msg_endpoint_t *ipc)
{
    g_atomic_int_inc(&ipc->refcount);
}

void
msg_endpoint_decref(msg_endpoint_t *ipc)
{
    if (!g_atomic_int_dec_and_test(&ipc->refcount))
        return;
    if (ipc->status == MSG_ENDPOINT_CONNECTED)
        msg_endpoint_disconnect(ipc);
    ipc->status = MSG_ENDPOINT_FREED;
    g_slice_free(msg_endpoint_t, ipc);
}

void
msg_endpoint_connect_to_socket(msg_endpoint_t *ipc, int sock)
{
    g_assert(ipc);
    g_assert(ipc->status == MSG_ENDPOINT_DISCONNECTED);

    msg_recv_state_t *state = &ipc->recv_state;
    state->queued_msgs = g_ptr_array_new();

    ipc->channel = g_io_channel_unix_new(sock);
    g_io_channel_set_encoding(ipc->channel, NULL, NULL);
    g_io_channel_set_buffered(ipc->channel, FALSE);
    state->watch_in_id = g_io_add_watch(ipc->channel, G_IO_IN, (GIOFunc)msg_recv, ipc);
    state->watch_hup_id = g_io_add_watch(ipc->channel, G_IO_HUP, (GIOFunc)msg_hup, ipc);

    ipc->status = MSG_ENDPOINT_CONNECTED;

    if (!endpoints)
        endpoints = g_ptr_array_sized_new(1);

    /* Add the endpoint; it should never be present already */
    g_assert(!g_ptr_array_remove_fast(endpoints, ipc));
    g_ptr_array_add(endpoints, ipc);
}

msg_endpoint_t *
msg_endpoint_replace(msg_endpoint_t *orig, msg_endpoint_t *new)
{
    g_assert(orig);
    g_assert(new);
    g_assert(orig->status == MSG_ENDPOINT_DISCONNECTED);
    g_assert(new->status == MSG_ENDPOINT_CONNECTED);

    msg_endpoint_incref(new);

    /* Send all queued messages */
    if (orig->queue) {
        g_io_channel_write_chars(new->channel,
                (gchar*)orig->queue->data,
                orig->queue->len, NULL, NULL);
        g_byte_array_unref(orig->queue);
    }
    orig->queue = NULL;

    msg_endpoint_decref(orig);
    return new;
}

void
msg_endpoint_disconnect(msg_endpoint_t *ipc)
{
    g_assert(ipc->status == MSG_ENDPOINT_CONNECTED);
    g_assert(ipc->channel);

    g_ptr_array_remove_fast(endpoints, ipc);

    /* Remove watches */
    msg_recv_state_t *state = &ipc->recv_state;
    g_source_remove(state->watch_in_id);
    g_source_remove(state->watch_hup_id);

    /* Close channel */
    g_io_channel_shutdown(ipc->channel, TRUE, NULL);
    ipc->status = MSG_ENDPOINT_DISCONNECTED;
    ipc->channel = NULL;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
