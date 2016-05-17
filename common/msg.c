#include "common/luaserialize.h"
#include "common/msg.h"

/* Prototypes for msg_recv_... functions */
#define X(name) void msg_recv_##name(const msg_lua_require_module_t *msg, guint length);
    MSG_TYPES
#undef X

typedef struct _msg_recv_state_t {
    msg_header_t hdr;
    gpointer payload;
    gsize bytes_read;
    gboolean hdr_done;
} msg_recv_state_t;

gboolean
msg_recv(GIOChannel *channel, GIOCondition cond, gpointer UNUSED(user_data))
{
    g_assert(cond & G_IO_IN);

    static msg_recv_state_t state;

    gchar *buf = (state.hdr_done ? state.payload : &state.hdr) + state.bytes_read;
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
        return TRUE;

    /* If we've just finished downloading the header... */
    if (!state.hdr_done) {
        /* ... update state, and try to download payload */
        state.hdr_done = TRUE;
        state.bytes_read = 0;
        state.payload = g_malloc(state.hdr.length);
        return msg_recv(channel, cond, NULL);
    }

    /* Otherwise, we finished downloading the message; dispatch it */

    switch (state.hdr.type) {
#define X(name) case MSG_TYPE_##name: \
    msg_recv_##name(state.payload, state.hdr.length); \
    break;
        MSG_TYPES
#undef X
        default:
            fatal("Web extension received message with an invalid type");
    }

    /* Reset state for the next message */

    g_free(state.payload);
    state.payload = NULL;
    state.bytes_read = 0;
    state.hdr_done = FALSE;

    return TRUE;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
