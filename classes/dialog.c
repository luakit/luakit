/*
 * dialog.c - Standard Gtk dialogs wrapper
 *
 * Copyright © 2009 Julien Danjou <julien@danjou.info>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 */

#include <gtk/gtk.h>

#include "globalconf.h"
#include "luah.h"
#include "classes/widget.h"
#include "classes/dialog.h"
#include "common/luaobject.h"

/* Shows a Gtk save dialog.
 * \param L The Lua VM state.
 * \return The number of objects pushed onto the stack.
 * \luastack
 * \lparam title The title of the dialog.
 * \lparam parent The parent window of the dialog or nil.
 * \lparam default_folder The folder to initially display in the dialog.
 * \lparam default_name The filename to preselect in the dialog.
 * \lreturn The name of the selected file or nil if the dialog was cancelled.
 */
static int
luaH_show_save_dialog(lua_State *L)
{
    const char *title = luaL_checkstring(L, 1);
    // decipher the parent
    GtkWindow *parent_window;
    if (lua_isnil(L, 2)) {
        parent_window = NULL;
    } else {
        widget_t *parent = luaH_checkudata(L, 2, &widget_class);
        if (GTK_IS_WINDOW(parent->widget)) {
            parent_window = GTK_WINDOW(parent->widget);
        } else {
            luaH_warn(L, "dialog expects a window as parent, but some other widget was given");
            parent_window = NULL;
        }
    }
    const char *default_folder = luaL_checkstring(L, 3);
    const char *default_name = luaL_checkstring(L, 4);
    GtkWidget *dialog = gtk_file_chooser_dialog_new(title,
            parent_window,
            GTK_FILE_CHOOSER_ACTION_SAVE,
            GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL,
            GTK_STOCK_SAVE, GTK_RESPONSE_ACCEPT,
            NULL);
    // set default folder, name and overwrite confirmation policy
    gtk_file_chooser_set_current_folder(GTK_FILE_CHOOSER(dialog), default_folder);
    gtk_file_chooser_set_current_name(GTK_FILE_CHOOSER(dialog), default_name);
    gtk_file_chooser_set_do_overwrite_confirmation(GTK_FILE_CHOOSER(dialog), TRUE);
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        gchar *filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
        lua_pushstring(L, filename);
        g_free(filename);
    } else {
        lua_pushnil(L);
    }
    gtk_widget_destroy(dialog);
    return 1;
}

void
dialog_lib_setup(lua_State *L)
{
    static const struct luaL_reg dialog_methods[] =
    {
        { "save", luaH_show_save_dialog },
        { NULL, NULL }
    };

    static const struct luaL_reg dialog_meta[] =
    {
        { NULL, NULL }
    };

    luaH_openlib(L, "dialog", dialog_methods, dialog_meta);
}

// vim: filetype=c:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:encoding=utf-8:textwidth=80
