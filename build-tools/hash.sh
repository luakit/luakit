#!/bin/sh
# script to determine git hash of current source tree

# set a variable when running `git --archive <hash/tag>` (this is what github does)
# alternatively, you could also git get-tar-commit-id < tarball (but that's a bit dirtier)
FROM_ARCHIVE=$Format:%H$

# ... but try to use whatever git tells us if there is a .git folder
if [ -d .git -a -r .git ]
then
	hash=$(git log 2>/dev/null | head -n1 2>/dev/null | sed "s/.* //" 2>/dev/null)
fi

if [ x"$hash" != x ]
then
	echo $hash
elif [ "$FROM_ARCHIVE" != ':%H$' ]
then
	echo $FROM_ARCHIVE
else
	echo "commit hash detection fail.  Dear packager, please figure out what goes wrong or get in touch with us" >&2
	echo UNKNOWN
	exit 2
fi
exit 0
