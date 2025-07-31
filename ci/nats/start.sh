#!/usr/bin/env bash

NATS_VERSION=2

if readlink -f . >/dev/null 2>&1 # {{{ makes readlink work on mac
then
    readlink=readlink
else
    if greadlink -f . >/dev/null 2>&1
    then
        readlink=greadlink
    else
        printf "You must install greadlink to use this (brew install coreutils)\n" >&2
    fi
fi # }}}

# Set here to the full path to this script
me=${BASH_SOURCE[0]}
[ -L "$me" ] && me=$($readlink -f "$me")
here=$(cd "$(dirname "$me")" && pwd)
just_me=$(basename "$me")
export just_me

cd "$here" || exit 1
if command -v podman 2>/dev/null
then
    runtime=podman
else
    runtime=docker
fi

set -x
exec "$runtime" run --rm -it -p 4222:4222 -p 6222:6222 -p 8222:8222 -v ./accounts.txt:/accounts.txt nats:"$NATS_VERSION" -js -c /accounts.txt "$@"
