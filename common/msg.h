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

GIOChannel * msg_setup(int sock);
gboolean msg_recv_and_dispatch_or_enqueue(int type_mask);
void msg_send_lua(msg_type_t type, lua_State *L, gint start, gint end);

/* Must be defined separately; not defined in common/msg.c */
void msg_send(const msg_header_t *header, const void *data);

#endif
