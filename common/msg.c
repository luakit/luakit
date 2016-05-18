#include "common/luaserialize.h"
#include "common/msg.h"

/* Prototypes for msg_recv_... functions */
#define X(name) void msg_recv_##name(const msg_lua_require_module_t *msg, guint length);
    MSG_TYPES
#undef X

typedef struct _msg_recv_state_t {
    GIOChannel *channel;
    GPtrArray *queued_msgs;

    msg_header_t hdr;
    gpointer payload;
    gsize bytes_read;
    gboolean hdr_done;
} msg_recv_state_t;

static msg_recv_state_t state;

typedef struct _queued_msg_t {
    msg_header_t header;
    char payload[0];
} queued_msg_t;

static void
msg_dispatch(msg_header_t header, gpointer payload)
{
    switch (header.type) {
#define X(name) case MSG_TYPE_##name: msg_recv_##name(payload, header.length); break;
        MSG_TYPES
#undef X
        default:
            fatal("Received message with invalid type 0x%x", header.type);
    }
}

static gboolean
msg_dispatch_enqueued(gpointer UNUSED(unused))
{
    if (state.queued_msgs->len > 0) {
        queued_msg_t *msg = g_ptr_array_index(state.queued_msgs, 0);
        /* Dispatch and free the message */
        msg_dispatch(msg->header, msg->payload);
        g_ptr_array_remove_index(state.queued_msgs, 0);
        g_slice_free1(sizeof(queued_msg_t) + state.hdr.length, state.payload);
        return TRUE;
    }
    return FALSE;
}

/* Callback function for channel watch */
static gboolean
msg_recv(GIOChannel *UNUSED(channel), GIOCondition cond, gpointer UNUSED(user_data))
{
    g_assert(cond & G_IO_IN);

    msg_dispatch_enqueued(NULL) || msg_recv_and_dispatch_or_enqueue(MSG_TYPE_ANY);

    return TRUE;
}

static gboolean
msg_hup(GIOChannel *channel, GIOCondition UNUSED(cond), gpointer UNUSED(user_data))
{
    g_io_channel_unref(channel);
    return FALSE;
}

GIOChannel *
msg_setup(int sock)
{
    state.queued_msgs = g_ptr_array_new();

    state.channel = g_io_channel_unix_new(sock);
    g_io_channel_set_encoding(state.channel, NULL, NULL);
    g_io_channel_set_buffered(state.channel, FALSE);
    g_io_add_watch(state.channel, G_IO_IN, msg_recv, NULL);
    g_io_add_watch(state.channel, G_IO_HUP, msg_hup, NULL);

    return state.channel;
}

/* Receive a single message
 * If the message matches the type mask, dispatch it; otherwise, enqueue it
 * Return true if a message was dispatched */
gboolean
msg_recv_and_dispatch_or_enqueue(int type_mask)
{
    g_assert(type_mask != 0);

    GIOChannel *channel = state.channel;

    gchar *buf = (state.hdr_done ? state.payload+sizeof(queued_msg_t) : &state.hdr) + state.bytes_read;
    gsize remaining = (state.hdr_done ? state.hdr.length : sizeof(state.hdr)) - state.bytes_read;
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
    state.bytes_read += bytes_read;
    remaining -= bytes_read;

    if (remaining > 0)
        return FALSE;

    /* If we've just finished downloading the header... */
    if (!state.hdr_done) {
        /* ... update state, and try to download payload */
        state.hdr_done = TRUE;
        state.bytes_read = 0;
        state.payload = g_slice_alloc(sizeof(queued_msg_t) + state.hdr.length);
        return msg_recv_and_dispatch_or_enqueue(type_mask);
    }

    /* Otherwise, we finished downloading the message */
    if (state.hdr.type & type_mask) {
        msg_dispatch(state.hdr, state.payload+sizeof(queued_msg_t));
        g_slice_free1(sizeof(queued_msg_t) + state.hdr.length, state.payload);
    } else {
        /* Copy the header into the space at the start of the payload slice */
        memcpy(state.payload, &state.hdr, sizeof(queued_msg_t));
        g_ptr_array_add(state.queued_msgs, state.payload);
        g_idle_add(msg_dispatch_enqueued, NULL);
    }

    /* Reset state for the next message */
    state.payload = NULL;
    state.bytes_read = 0;
    state.hdr_done = FALSE;

    /* Return true if we dispatched it */
    return state.hdr.type & type_mask;
}

void
msg_send_lua(msg_type_t type, lua_State *L, gint start, gint end)
{
    GByteArray *buf = g_byte_array_new();
    lua_serialize_range(L, buf, start, end);
    msg_header_t header = { .type = type, .length = buf->len };
    msg_send(&header, buf->data);
    g_byte_array_unref(buf);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
