#!/usr/bin/env bash

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

: "${GEM_NAME:=leopard}"
: "${GIT_ORG:=rubyists}"

GEM_HOST=$1
: "${GEM_HOST:=rubygems}"

case "$GEM_HOST" in
    rubygems)
        gem_key='rubygems'
        gem_host='https://rubygems.org'
        ;;
    github)
        gem_key='github'
        gem_host="https://rubygems.pkg.github.com/$GIT_ORG"
        # Replace the gem host in the gemspec, so it allows pushing to the GitHub package registry
        sed --in-place=.bak -e "s|https://rubygems.org|https://rubygems.pkg.github.com/$GIT_ORG|" "$here/../$GEM_NAME".gemspec
        # Restore the original gemspec after the script finishes
        trap 'mv -v "$here/../$GEM_NAME".gemspec.bak "$here/../$GEM_NAME".gemspec' EXIT
        ;;
    *)
        printf 'Unknown GEM_HOST: %s\n' "$GEM_HOST" >&2
        exit 1
        ;;
esac

# We only want this part running in CI, with no ~/.gem dir
# For local testing, you should have a ~/.gem/credentials file with
# the keys you need to push to rubygems or github
if [ ! -d ~/.gem ]
then
    if [ -z "$GEM_TOKEN" ]
    then
        printf 'No GEM_TOKEN provided, cannot publish\n' >&2
        exit 1
    fi
    mkdir -p ~/.gem
    printf '%s\n:%s: %s\n' '---' "$gem_key" "$GEM_TOKEN" > ~/.gem/credentials
    chmod 600 ~/.gem/credentials
fi

if [ -f "$here"/../.version.txt ]
then
    version=$(<"$here"/../.version.txt)
else
    version=$(git describe --tags --abbrev=0 | sed -e 's/^v//')
fi

if [ -z "$version" ]
then
    gem="$(ls ../../"$GEM_NAME"-*.gem | tail -1)"
else
    gem="$(printf '%s/../%s-%s.gem' "$here" "$GEM_NAME" "$version")"
fi

if [ ! -f "$gem" ]
then
    printf 'No gem file found: %s\n' "$gem" >&2
    exit 1
fi

if [[ "${TRACE:-false}" == true || "${ACTIONS_STEP_DEBUG:-false}" == true ]]
then
    printf "DEBUG: [%s] Building And Publishing %s to %s\n" "$just_me" "$gem" "$gem_host" >&2
fi

bundle exec gem build
bundle exec gem push -k "$gem_key" --host "$gem_host" "$(basename "$gem")"

# vim: set foldmethod=marker et ts=4 sts=4 sw=4 ft=bash :
