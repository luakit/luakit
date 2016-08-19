#include "common/lualib.h"
#include "common/luaserialize.h"
#include "common/msg.h"

/* Prototypes for msg_recv_... functions */
#define X(name) void msg_recv_##name(msg_endpoint_t *from, const void *msg, guint length);
    MSG_TYPES
#undef X

typedef struct _msg_recv_state_t {
    GIOChannel *channel;
    guint watch_in_id, watch_hup_id;
    GPtrArray *queued_msgs;

    msg_header_t hdr;
    gpointer payload;
    gsize bytes_read;
    gboolean hdr_done;
} msg_recv_state_t;

/*
 * Default process name is "UI" because the UI process currently sends IPC
 * messages before the IPC channel is opened (these messages are queued),
 * and sending IPC messages writes log messages which include the process
 * name.
 */
static const char *process_name = "UI";

static GThread *send_thread;
static GAsyncQueue *send_queue;
static GHashTable *endpoint_recv_states;

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
                process_name, msg_type_name(header.type));
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
    msg_recv_state_t *state = g_hash_table_lookup(endpoint_recv_states, from);

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
        msg_send_impl(ipc, header, data);
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
                process_name, msg_type_name(header->type));

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
msg_recv(GIOChannel *UNUSED(channel), GIOCondition cond, gpointer from)
{
    g_assert(cond & G_IO_IN);

    (void) (msg_dispatch_enqueued(from) || msg_recv_and_dispatch_or_enqueue(from, MSG_TYPE_ANY));

    return TRUE;
}

static gboolean
msg_hup(GIOChannel *channel, GIOCondition UNUSED(cond), gpointer from)
{
    msg_recv_state_t *state = g_hash_table_lookup(endpoint_recv_states, from);
    g_source_remove(state->watch_in_id);
    g_source_remove(state->watch_hup_id);
    g_io_channel_shutdown(channel, TRUE, NULL);
    return FALSE;
}

GIOChannel *
msg_create_channel_from_socket(msg_endpoint_t *ipc, int sock, const char *proc_name)
{
    g_assert(ipc);

    if (!endpoint_recv_states)
        endpoint_recv_states = g_hash_table_new(g_direct_hash, g_direct_equal);

    msg_recv_state_t *state = g_slice_new0(msg_recv_state_t);
    g_hash_table_insert(endpoint_recv_states, ipc, state);

    state->queued_msgs = g_ptr_array_new();
    g_assert(proc_name && *proc_name);
    process_name = proc_name;

    state->channel = g_io_channel_unix_new(sock);
    g_io_channel_set_encoding(state->channel, NULL, NULL);
    g_io_channel_set_buffered(state->channel, FALSE);
    state->watch_in_id = g_io_add_watch(state->channel, G_IO_IN, msg_recv, ipc);
    state->watch_hup_id = g_io_add_watch(state->channel, G_IO_HUP, msg_hup, ipc);

    return state->channel;
}

/* Receive a single message
 * If the message matches the type mask, dispatch it; otherwise, enqueue it
 * Return true if a message was dispatched */
gboolean
msg_recv_and_dispatch_or_enqueue(msg_endpoint_t *from, int type_mask)
{
    g_assert(from);
    g_assert(type_mask != 0);

    msg_recv_state_t *state = g_hash_table_lookup(endpoint_recv_states, from);

    GIOChannel *channel = state->channel;

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

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
