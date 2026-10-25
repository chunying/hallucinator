#!/bin/sh

if [ ! -z "${USER_UID}" -a ! -z "${USER_GID}" ]; then
    chown -R "${USER_UID}:${USER_GID}" /db
fi

exec /sbin/tini "$@"
