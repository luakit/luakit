#!/bin/bash
# Get the current Debian branch.

GBP_CONF_FILE=${1:-"debian/gbp.conf"}

if [ -f ${GBP_CONF_FILE} ]; then
    egrep '^debian-branch *= *.*$' ${GBP_CONF_FILE} | cut -d "=" -f 2 | sed -E -e 's/ +//g'
else
    echo "ERROR: the git-buildpackage configuration file ${GBP_CONF_FILE} does not exist" >&2
    exit 2
fi
exit 0
