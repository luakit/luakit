#ifndef EXTENSION_MSG_H
#define EXTENSION_MSG_H

#define MSG_TYPES \
	X(lua_require_module) \

#define X(name) MSG_TYPE_##name,
typedef enum { MSG_TYPES } msg_type_t;
#undef X

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

gboolean
msg_recv(GIOChannel *channel, GIOCondition cond, gpointer user_data);

#endif /* end of include guard: EXTENSION_MSG_H */
