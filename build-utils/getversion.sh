#!/bin/sh
# Get the current version using various methods.

# The following will serve as a fallback version string (which is the short
# hash of the latest commit before the application was packaged (if it was
# packaged)). You will find that this file is listed inside the .gitattributes
# file like so:
#
#   ./build-utils/getversion.sh export-subst
#
# This tells git to replace the format string in the following line with the
# current short hash upon the calling of the `git archive <hash/tag>` command.
VERSION_FROM_ARCHIVE=$Format:%h$

# The preferred method is to use the git describe command but this is only
# possible if the .git directory is present.
if [ -d .git -a -r .git ]
then
    VERSION_FROM_GIT=$(git describe --tags --always)
fi

if [ x"$VERSION_FROM_GIT" != x ]; then
    echo $VERSION_FROM_GIT; exit 0;
fi

if [ "$VERSION_FROM_ARCHIVE" != ':%h$' ]; then
    echo $VERSION_FROM_ARCHIVE; exit 0;
fi

echo "ERROR: Commit hash detection failure. Dear packager, please figure out"\
     "what has gone wrong and or get in touch with us." >&2

exit 2

# vim: ft=sh:et:sw=4:ts=8:sts=4:tw=80
