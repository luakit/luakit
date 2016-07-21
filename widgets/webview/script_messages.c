/*
 * widgets/webview/script_messages.c - webkit script message support
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

typedef struct _script_message_data_t {
	widget_t *widget;
	const gchar *name;
} script_message_data_t;

static void
script_message_received_cb(WebKitUserContentManager *UNUSED(manager),
        WebKitJavascriptResult *js_result, script_message_data_t *info)
{
    lua_State *L = globalconf.L;
    JSContextRef context = webkit_javascript_result_get_global_context(js_result);
    JSValueRef result = webkit_javascript_result_get_value(js_result);
    gchar *error = NULL;
	widget_t *w = info->widget;
    webview_data_t *d = w->data;

    luaH_object_push(L, w->ref);
    lua_pushstring(L, info->name);
    if (!luaJS_pushvalue(L, context, result, &error)) {
        warn("script message handler for '%s': %s", info->name, error);
		lua_pop(L, 2);
        return;
    }

	signal_array_emit(L, d->script_msg_signals, info->name, "script-message", 3, 0);
}

static void
script_message_data_destroy(script_message_data_t *info, GClosure *UNUSED(closure))
{
	g_slice_free(script_message_data_t, info);
}

static gint
luaH_webview_add_script_signal(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    const gchar *name = luaL_checkstring(L, 2);
    luaH_checkfunction(L, 3);
    gpointer ref = luaH_object_ref(L, 3);

    if (!signal_lookup(d->script_msg_signals, name)) {
		script_message_data_t *info = g_slice_new(script_message_data_t);
		info->name = g_strdup(name);
		info->widget = d->widget;

        /* Attach a signal handler with the right signal detail */
		gchar *signame = g_strdup_printf("script-message-received::%s", name);
		g_signal_connect_data(G_OBJECT(d->user_content), signame,
                G_CALLBACK(script_message_received_cb), info,
				(GClosureNotify) script_message_data_destroy, 0);
		webkit_user_content_manager_register_script_message_handler(d->user_content, name);
		g_free(signame);
    }

	signal_add(d->script_msg_signals, name, ref);
    return 0;
}

static gint
luaH_webview_remove_script_signal(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    const gchar *name = luaL_checkstring(L, 2);
    luaH_checkfunction(L, 3);

    gpointer ref = (gpointer) lua_topointer(L, 3);
    signal_remove(d->script_msg_signals, name, ref);

    if (!signal_lookup(d->script_msg_signals, name)) {
		webkit_user_content_manager_unregister_script_message_handler(d->user_content, name);
		guint signal_id = g_signal_lookup("script-message-received", WEBKIT_TYPE_USER_CONTENT_MANAGER);
		GQuark detail = g_quark_from_string(name);
		g_signal_handlers_disconnect_matched(d->user_content,
				G_SIGNAL_MATCH_ID|G_SIGNAL_MATCH_DETAIL|G_SIGNAL_MATCH_FUNC,
				signal_id, detail, NULL, G_CALLBACK(script_message_received_cb), NULL);
	}

    return 0;
}
