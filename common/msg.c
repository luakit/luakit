#include "common/lualib.h"
#include "common/luaserialize.h"
#include "common/msg.h"

/* Prototypes for msg_recv_... functions */
#define X(name) void msg_recv_##name(msg_endpoint_t *from, const void *msg, guint length);
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

typedef struct _queued_msg_t {
    msg_header_t header;
    char payload[0];
    msg_endpoint_t *from;
} queued_msg_t;

static void
msg_dispatch(msg_endpoint_t *from, msg_header_t header, gpointer payload)
{
    if (header.type != MSG_TYPE_log)
        debug("Process '%s': recv " ANSI_COLOR_BLUE "%s" ANSI_COLOR_RESET " message",
                from->name, msg_type_name(header.type));
    switch (header.type) {
#define X(name) case MSG_TYPE_##name: msg_recv_##name(from, payload, header.length); break;
        MSG_TYPES
#undef X
        default:
            fatal("Received message with invalid type 0x%x", header.type);
    }
}

static gboolean
msg_dispatch_enqueued(msg_endpoint_t *from)
{
    msg_recv_state_t *state = &from->recv_state;

    if (state->queued_msgs->len > 0) {
        queued_msg_t *msg = g_ptr_array_index(state->queued_msgs, 0);
        /* Dispatch and free the message */
        msg_dispatch(msg->from, msg->header, msg->payload);
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
        msg_endpoint_t *ipc = g_async_queue_pop(send_queue);
        msg_header_t *header = g_async_queue_pop(send_queue);
        gpointer data = header->length ? g_async_queue_pop(send_queue) : NULL;

        if (ipc->channel) {
            g_io_channel_write_chars(ipc->channel, (gchar*)header, sizeof(*header), NULL, NULL);
            g_io_channel_write_chars(ipc->channel, (gchar*)data, header->length, NULL, NULL);
        } else {
            g_byte_array_append(ipc->queue, (guint8*)header, sizeof(*header));
            g_byte_array_append(ipc->queue, (guint8*)data, header->length);
        }

        g_free(header);
        g_free(data);
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
    g_assert((header->length == 0) == (data == NULL));
    gpointer header_dup = g_memdup(header, sizeof(*header));
    g_async_queue_push(send_queue, ipc);
    g_async_queue_push(send_queue, header_dup);
    if (header->length) {
        gpointer data_dup = g_memdup(data, header->length);
        g_async_queue_push(send_queue, data_dup);
    }
}

/* Callback function for channel watch */
static gboolean
msg_recv(GIOChannel *UNUSED(channel), GIOCondition cond, msg_endpoint_t *from)
{
    g_assert(cond & G_IO_IN);

    (void) (msg_dispatch_enqueued(from) || msg_recv_and_dispatch_or_enqueue(from, MSG_TYPE_ANY));

    return TRUE;
}

#ifndef LUAKIT_WEB_EXTENSION
void msg_endpoint_remove_from_endpoints(msg_endpoint_t *);
#endif

static gboolean
msg_hup(GIOChannel *UNUSED(channel), GIOCondition UNUSED(cond), msg_endpoint_t *from)
{
#ifndef LUAKIT_WEB_EXTENSION
    msg_endpoint_remove_from_endpoints(from);
#endif
    msg_endpoint_disconnect(from);
    return FALSE;
}

/* Receive a single message
 * If the message matches the type mask, dispatch it; otherwise, enqueue it
 * Return true if a message was dispatched */
gboolean
msg_recv_and_dispatch_or_enqueue(msg_endpoint_t *from, int type_mask)
{
    g_assert(from);
    g_assert(type_mask != 0);

    msg_recv_state_t *state = &from->recv_state;
    GIOChannel *channel = from->channel;

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
        return msg_recv_and_dispatch_or_enqueue(from, type_mask);
    }

    /* Otherwise, we finished downloading the message */
    if (state->hdr.type & type_mask) {
        msg_dispatch(from, state->hdr, state->payload+sizeof(queued_msg_t));
        g_slice_free1(sizeof(queued_msg_t) + state->hdr.length, state->payload);
    } else {
        /* Copy the header into the space at the start of the payload slice */
        memcpy(state->payload, &state->hdr, sizeof(queued_msg_t));
        g_ptr_array_add(state->queued_msgs, state->payload);
        g_idle_add((GSourceFunc)msg_dispatch_enqueued, from);
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

void
msg_endpoint_init(msg_endpoint_t *ipc, const gchar *name)
{
    memset(ipc, 0, sizeof(*ipc));
    ipc->name = (gchar*)name;
    ipc->queue = g_byte_array_new();
    ipc->status = MSG_ENDPOINT_DISCONNECTED;
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
}

msg_endpoint_t *
msg_endpoint_replace(msg_endpoint_t *orig, msg_endpoint_t *new)
{
    g_assert(orig);
    g_assert(new);
    g_assert(orig->status == MSG_ENDPOINT_DISCONNECTED);
    g_assert(new->status == MSG_ENDPOINT_CONNECTED);

    /* Send all queued messages */
    g_assert(orig->queue);
    g_io_channel_write_chars(new->channel,
            (gchar*)orig->queue->data,
            orig->queue->len, NULL, NULL);
    g_byte_array_unref(orig->queue);
    orig->queue = NULL;

    msg_endpoint_free(orig);
    return new;
}

void
msg_endpoint_disconnect(msg_endpoint_t *ipc)
{
    /* Remove watches */
    msg_recv_state_t *state = &ipc->recv_state;
    g_source_remove(state->watch_in_id);
    g_source_remove(state->watch_hup_id);

    /* Close channel */
    g_io_channel_shutdown(ipc->channel, TRUE, NULL);
    ipc->status = MSG_ENDPOINT_DISCONNECTED;
    ipc->channel = NULL;
}

void
msg_endpoint_free(msg_endpoint_t *ipc)
{
    ipc->status = MSG_ENDPOINT_FREED;
    g_slice_free(msg_endpoint_t, ipc);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
