/*
 * Copyright © 2017 Aidan Holm <aidanholm@gmail.com>
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

#include <errno.h>
#include <unistd.h>

#include "buildopts.h"
#include "common/resource.h"
#include "common/log.h"

static gchar *resource_path;
static gchar **resource_paths;

void
resource_path_set(const gchar *path)
{
    verbose("setting resource path '%s'", path);
    g_free(resource_path);
    resource_path = g_strdup(path);
    resource_paths = NULL;
}

gchar *
resource_path_get()
{
    return resource_path;
}

gchar *
resource_find_file(const gchar *path)
{
    g_assert(path);
    verbose("finding resource file '%s'", path);

    if (path[0] == '/')
        return g_strdup(path);

    if (!resource_paths)
        resource_paths = g_strsplit(resource_path, ";", 0);

    for (char **p = resource_paths; *p; p++) {
        gchar *full_path = g_build_filename(*p, path, NULL);
        if (access(full_path, R_OK))
            debug("tried path '%s': %s", full_path, g_strerror(errno));
        else {
            verbose("found resource file at '%s'", full_path);
            return full_path;
        }
        g_free(full_path);
    }

    verbose("no resource file found for '%s'", path);
    return NULL;
}

__attribute__((constructor)) static void
resource_init(void)
{
    resource_path = g_strdup("./resources;"LUAKIT_INSTALL_PATH"/resources");
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
