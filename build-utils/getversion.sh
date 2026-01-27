#!/bin/sh
# Get the current version using various methods.
#
# Output format examples:
#   No tags:        0.0.0-306393a or 0.0.0-306393a-dirty
#   With tag:       1.0.0 or 1.0.0-dirty
#   Tag + commits:  1.0.0-17-gfc5d7f2 or 1.0.0-17-gfc5d7f2-dirty
#
# The following will serve as a fallback version string (which is the short
# hash of the latest commit before the application was packaged (if it was
# packaged)). You will find that this file is listed inside the .gitattributes
# file like so:
#
#   ./build-utils/getversion.sh export-subst
#
# This tells git to replace the format string in the following line with the
# current hash upon the calling of the `git archive <hash/tag>` command.
VERSION_FROM_ARCHIVE='$Format:%H$'

# Check if we have a git repository (directory or worktree file)
if [ -d .git ] || { [ -f .git ] && grep -q '^gitdir:' .git 2>/dev/null; }
then
    VERSION_FROM_GIT=$(git describe --tags --always --dirty 2>/dev/null)
fi

# Format version: prepend 0.0.0- if no tag (output is just hash with optional -dirty)
# Version tags contain dots (e.g., 1.0.0), commit hashes don't (e.g., 306393a)
format_version() {
    ver="$1"
    case "$ver" in
        *.*)
            # Contains a dot - has a version tag
            echo "$ver"
            ;;
        *)
            # No dot - just commit hash (possibly with -dirty suffix)
            echo "0.0.0-$ver"
            ;;
    esac
}

if [ -n "$VERSION_FROM_GIT" ]; then
    format_version "$VERSION_FROM_GIT"
    exit 0
fi

# Fallback: version from git archive substitution
if [ "$VERSION_FROM_ARCHIVE" != '$Format:%H$' ]; then
    # Use short hash (first 7 characters)
    short_hash=$(echo "$VERSION_FROM_ARCHIVE" | cut -c1-7)
    format_version "$short_hash"
    exit 0
fi

echo "ERROR: Version detection failed. Not a git repo and no archive hash." >&2
exit 2

# vim: ft=sh:et:sw=4:ts=8:sts=4:tw=80
