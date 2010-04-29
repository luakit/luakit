#include "luakit.h"
#include "util.h"

/* Print error and exit with EXIT_FAILURE code. */
void
_fatal(int line, const char *fct, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    g_fprintf(stderr, "E: luakit: %s:%d: ", fct, line);
    g_vfprintf(stderr, fmt, ap);
    va_end(ap);
    g_fprintf(stderr, "\n");
    exit(EXIT_FAILURE);
}

/* Print error message on stderr. */
void
_warn(int line, const char *fct, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    g_fprintf(stderr, "W: luakit: %s:%d: ", fct, line);
    g_vfprintf(stderr, fmt, ap);
    va_end(ap);
    g_fprintf(stderr, "\n");
}

/* Print debug message on stderr. */
void
_debug(int line, const char *fct, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    g_fprintf(stderr, "D: luakit: %s:%d: ", fct, line);
    g_vfprintf(stderr, fmt, ap);
    va_end(ap);
    g_fprintf(stderr, "\n");
}
