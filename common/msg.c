#include "common/msg.h"

#include <assert.h>

gboolean
msg_recv(GIOChannel *channel, GIOCondition cond, gpointer UNUSED(user_data))
{
    assert(cond & G_IO_IN);
    GIOStatus s;

    /* Read the message header */

    msg_header_t header;
    switch ((s = g_io_channel_read_chars(channel, (gchar*)&header, sizeof(header), NULL, NULL))) {
        case G_IO_STATUS_NORMAL:
            break;
        default:
            /* TODO: error */
            break;
    }

    /* Read the message body */

    const void *payload = g_alloca(header.length);
    switch ((s = g_io_channel_read_chars(channel, (gchar*)payload, header.length, NULL, NULL))) {
        case G_IO_STATUS_NORMAL:
            break;
        default:
            /* TODO: error */
            break;
    }

    /* Dispatch the message */

    switch (header.type) {
#define X(name) case MSG_TYPE_##name: \
    msg_recv_##name(payload, header.length); \
    break;
        MSG_TYPES
#undef X
        default:
            fatal("Web extension received message with an invalid type");
    }

    return TRUE;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
