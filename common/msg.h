#ifndef LUAKIT_COMMON_MSG_H
#define LUAKIT_COMMON_MSG_H

#include <glib.h>
#include "common/util.h"

#define MSG_TYPES \
    X(lua_require_module) \
    X(lua_msg) \
    X(scroll) \
    X(web_lua_loaded) \
    X(lua_js_call) \
    X(lua_js_register) \
    X(lua_js_gc) \
    X(web_extension_loaded) \
    X(eval_js) \
    X(log) \

#define X(name) MSG_TYPE_EXPONENT_##name,
typedef enum { MSG_TYPES } _msg_type_exponent_t;
#undef X

/* Automatically defines all MSG_TYPE_foo as powers of two */
#define X(name) MSG_TYPE_##name = (1 << MSG_TYPE_EXPONENT_##name),
typedef enum { MSG_TYPES } msg_type_t;
#undef X

#define MSG_TYPE_ANY (-1)

/** Fixed size header prepended to each message */
typedef struct _msg_header_t {
    /** The length of the message in bytes, not including the header */
    guint length;
    /** The type of the message, fairly self-explanatory... */
    msg_type_t type;
} msg_header_t;

/* Structure of messages for all message types */

typedef struct _msg_lua_require_module_t {
    gchar module_name[0];
} msg_lua_require_module_t;

typedef struct _msg_lua_msg_t {
    gchar arg[0];
} msg_lua_msg_t;

typedef enum {
    MSG_SCROLL_TYPE_docresize,
    MSG_SCROLL_TYPE_winresize,
    MSG_SCROLL_TYPE_scroll
} msg_scroll_subtype_t;

typedef struct _msg_scroll_t {
    gint h, v;
    guint64 page_id;
    msg_scroll_subtype_t subtype;
} msg_scroll_t;

/* Message names */
static inline const char *
msg_type_name(msg_type_t type)
{
    switch (type) {
#define X(name) case MSG_TYPE_##name: return #name;
        MSG_TYPES
#undef X
        default:
            return "UNKNOWN";
    }
}

typedef struct _msg_recv_state_t {
    guint watch_in_id, watch_hup_id;
    GPtrArray *queued_msgs;

    msg_header_t hdr;
    gpointer payload;
    gsize bytes_read;
    gboolean hdr_done;
} msg_recv_state_t;

typedef struct _msg_endpoint_t {
    /** Channel for IPC with web process */
    GIOChannel *channel;
    /** Queued data for when channel is not yet open */
    GByteArray *queue;
    /** Incoming message bookkeeping data */
    msg_recv_state_t recv_state;
} msg_endpoint_t;

GIOChannel * msg_create_channel_from_socket(msg_endpoint_t *ipc, int sock, const char *process_name);
gboolean msg_recv_and_dispatch_or_enqueue(msg_endpoint_t *ipc, int type_mask);
void msg_send_lua(msg_endpoint_t *ipc, msg_type_t type, lua_State *L, gint start, gint end);
void msg_send(msg_endpoint_t *ipc, const msg_header_t *header, const void *data);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
