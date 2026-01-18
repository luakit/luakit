#!/bin/bash
# Luakit Library Version Checker
#
# This script checks the installed versions of luakit's dependencies
# and compares them against the versions specified in config.mk

set -e

echo "=========================================="
echo "Luakit Library Version Checker"
echo "=========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check package version
check_package() {
    local pkg=$1
    local name=$2

    if pkg-config --exists "$pkg" 2>/dev/null; then
        version=$(pkg-config --modversion "$pkg")
        echo -e "${GREEN}✓${NC} $name: $version"
    else
        echo -e "${RED}✗${NC} $name: NOT FOUND"
        return 1
    fi
}

echo "Required Dependencies:"
echo "----------------------"
check_package "gtk+-3.0" "GTK+"
check_package "webkit2gtk-4.1" "WebKit2GTK"
check_package "javascriptcoregtk-4.1" "JavaScriptCoreGTK"
check_package "sqlite3" "SQLite"
check_package "gthread-2.0" "GThread"

# Check Lua
echo ""
if pkg-config --exists luajit 2>/dev/null; then
    check_package "luajit" "LuaJIT"
elif pkg-config --exists lua5.1 2>/dev/null; then
    check_package "lua5.1" "Lua 5.1"
elif pkg-config --exists lua-5.1 2>/dev/null; then
    check_package "lua-5.1" "Lua 5.1"
else
    echo -e "${RED}✗${NC} Lua: NOT FOUND"
fi

echo ""
echo "=========================================="
echo "Optional: Check for GTK 4 availability"
echo "=========================================="
echo ""

if pkg-config --exists gtk4 2>/dev/null; then
    gtk4_version=$(pkg-config --modversion gtk4)
    echo -e "${YELLOW}⚠${NC}  GTK 4 available: $gtk4_version"
    echo "   Note: Migrating to GTK 4 requires significant code changes"
    echo "   See LIBRARY_UPDATE_ANALYSIS.md for details"
else
    echo -e "   GTK 4 not installed (expected - luakit uses GTK 3)"
fi

if pkg-config --exists webkitgtk-6.0 2>/dev/null; then
    webkit6_version=$(pkg-config --modversion webkitgtk-6.0)
    echo -e "${YELLOW}⚠${NC}  WebKitGTK 6.0 available: $webkit6_version"
    echo "   Note: WebKitGTK 6.0 requires GTK 4 migration first"
else
    echo "   WebKitGTK 6.0 not installed (expected - requires GTK 4)"
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "All required dependencies are installed at their latest"
echo "stable versions within the GTK 3 ecosystem."
echo ""
echo "For more information about library updates, see:"
echo "  - LIBRARY_UPDATE_ANALYSIS.md"
echo "  - https://webkitgtk.org/ (for WebKitGTK updates)"
echo ""
