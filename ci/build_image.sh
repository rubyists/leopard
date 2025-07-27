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

repo_top=$(git rev-parse --show-toplevel)
cd "$repo_top" || {
    printf "Could not cd to %s\n" "$repo_top" >&2
    exit 1
}

base_dir=$(basename "$(pwd)")
: "${UBUNTU_VERSION:=bookworm}"
: "${BUILD_CONTEXT:=$(pwd)}"
: "${IMAGE_NAME:=$base_dir}"
: "${LICENSE:=MIT}"
: "${REGISTRY:=ghcr.io}"
: "${RUBY_VERSION:=3.3.6}"
: "${REGISTRY_TOKEN:=$GITHUB_TOKEN}"

base_image_tag="$RUBY_VERSION-$UBUNTU_VERSION"
base_exists=$(skopeo list-tags docker://docker.io/ruby |jq -r "any(.Tags[] == \"$base_image_tag\"; .)")
if [ "$base_exists" = "false" ]
then
    printf "Base image %s does not exist at docker.io/ruby, cannot build.\n" "$base_image_tag" >&2
    exit 99
fi

usage() { # {{{
    cat <<-EOT
    Build an image, optionally pushing it to the registry

    Usage: $0 <options> <image_tag>
        Options:
            -c CONTAINERFILE  Path to the containerfile (default: ./oci/Containerfile)
            -C CONTEXT        Build context (default: $BUILD_CONTEXT)
            -i NAME           Name of the image (default: $IMAGE_NAME)
            -l LICENSE        License of the image (default: $LICENSE)
            -r REGISTRY       Registry to push the image to when -p is given (default: $REGISTRY)
            -p                Push the image to the registry
            -h                Show help / usage
EOT
} # }}}

die() { # {{{
    local -i code
    code=$1
    shift
    error "$*"
    printf "\n" >&2
    usage >&2
    # shellcheck disable=SC2086
    exit $code
} # }}}

## Logging functions # {{{
log() { # {{{
    printf "%s [%s] <%s> %s\n" "$(date '+%Y-%m-%d %H:%M:%S.%6N')" "$$" "${just_me:-$0}" "$*"
} # }}}

debug() { # {{{
    [ $verbose -lt 2 ] && return 0
    # shellcheck disable=SC2059
    log_line=$(printf "$@")
    log "[DEBUG] $log_line" >&2
} # }}}

warn() { # {{{
    # shellcheck disable=SC2059
    log_line=$(printf "$@")
    log "[WARN] $log_line" >&2
} # }}}

error() { # {{{
    # shellcheck disable=SC2059
    log_line=$(printf "$@")
    log "[ERROR] $log_line" >&2
} # }}}

info() { # {{{
    [ $verbose -lt 1 ] && return 0
    # shellcheck disable=SC2059
    log_line=$(printf "$@")
    log "[INFO] $log_line" >&2
} # }}}
# }}}

push=0
verbose=0
while getopts :hpvc:C:i:l:r: opt # {{{
do
    case $opt in
        c)
            CONTAINERFILE=$OPTARG
            ;;
        C)
            BUILD_CONTEXT=$OPTARG
            ;;
        i)
            IMAGE_NAME=$OPTARG
            ;;
        l)
            LICENSE=$OPTARG
            ;;
        r)
            REGISTRY=$OPTARG
            ;;
        p)
            push=1
            ;;
        v)
            verbose=$((verbose + 1))
            ;;
        h)
            usage
            exit
            ;;
        :)
            printf "Option %s requires an argument\n" "$OPTARG" >&2
            usage >&2
            exit 28
            ;;
        ?)
            printf "Invalid option '%s'\n" "$OPTARG" >&2
            usage >&2
            exit 27
            ;;
    esac
done # }}}
shift $((OPTIND-1))

tag=$1
[ -z "$tag" ] && die 1 "Missing image tag"
shift

# Check for extra argument
if [ $# -gt 0 ]; then
    # If we have the special argument '--' we shift it away, otherwise we die
    [ "$1" != '--' ] && die 2 "Too many arguments"
    # Once this is shifted away, the rest of the arguments are passed to the build command, below
    shift
fi

if [ -z "$CONTAINERFILE" ]; then
    printf "No containerfile specified, looking for default locations\n"
    for containerfile in Containerfile Dockerfile
    do
        if [ -f ./oci/"$containerfile" ]; then
            debug "Found ./oci/%s\n" "$containerfile"
            containerfile=./oci/"$containerfile"
            break
        fi
        if [ -f "$containerfile" ]; then
            debug "Found %s\n" "$containerfile"
            break
        fi
    done
else
    [ -f "$CONTAINERFILE" ] || die 3 "Containerfile '$CONTAINERFILE' not found"
    debug "Using containerfile %s\n" "$CONTAINERFILE"
    containerfile=$CONTAINERFILE
fi

[ -f "$containerfile" ] || die 4 "No containerfile found"

[ -d "$BUILD_CONTEXT" ] || die 5 "Build context '$BUILD_CONTEXT' not found"

debug 'Building image from %s in in %s\n' "$containerfile" "$here"
# Build the image
if command -v podman 2>/dev/null
then
    runtime=podman
elif command -v docker 2>/dev/null
then
    runtime=docker
else
    die 6 "No container runtime found"
fi

revision=$(git rev-parse HEAD)
shortref=$(git rev-parse --short "$revision")
repo_url=$(git remote get-url origin)
if [ -z "$repo_url" ]
then
    die 7 "No remote found"
fi
if [[ $repo_url == *github.com/* ]]
then
    owner_and_repo=${repo_url#*github.com/}
else
    owner_and_repo=${repo_url##*:}
fi
# Get rid of the trailing .git
service=$(basename "$owner_and_repo" .git)
owner=$(dirname "$owner_and_repo")

full_tag=$IMAGE_NAME:$tag
# Pass any extra arguments to the build command ("$@" contains the rest of the arguments)
$runtime build --tag "$full_tag" "$@" \
               --label org.opencontainers.image.created="$(date --utc --iso-8601=seconds)" \
               --label org.opencontainers.image.description="Image for $service" \
               --label org.opencontainers.image.licenses="$LICENSE" \
               --label org.opencontainers.image.revision="$revision" \
               --label org.opencontainers.image.url="$repo_url" \
               --label org.opencontainers.image.title="$IMAGE_NAME" \
               --label org.opencontainers.image.source="Generated by ruby-automation's build_image.sh ($USER@$HOSTNAME)" \
               --label org.opencontainers.image.version="$full_tag" \
               --label shortref="$shortref" \
               --build-arg UBUNTU_VERSION="$UBUNTU_VERSION" \
               --build-arg RUBY_VERSION="$RUBY_VERSION" \
               -f "$containerfile" "$BUILD_CONTEXT" || die 8 "Failed to build image"

[ $push -eq 1 ] || exit 0
if ! $runtime login --get-login "$REGISTRY" >/dev/null 2>/dev/null
then
    printf "Not logged in to '%s', trying to login\n" "$REGISTRY" >&2
    [ -z "$REGISTRY_TOKEN" ] && die 9 "No REGISTRY_TOKEN (nor GITHUB_TOKEN) set, cannot login"
    printf "%s" "$REGISTRY_TOKEN" | $runtime login -u "$REGISTRY_TOKEN" --password-stdin "$REGISTRY" || die 10 "Failed to login to $REGISTRY"
fi

# Split 1.2.3 into 1.2.3, 1.2, 1. We want to tag our image with all 3 of these
mapfile -t tags < <(echo "$tag" | awk -F'.' 'NF==3{print; print $1"."$2; print $1; next} NF==2{print; print $1; next} {print}')
for t in "${tags[@]}"
do
    new_tag=$IMAGE_NAME:$t
    registry_image_name="$REGISTRY/$owner/$new_tag"
    if [ "$runtime" = "podman" ]
    then
        if [ "$full_tag" != "$new_tag" ]
        then
            debug "Tagging %s as %s\n" "$full_tag" "$new_tag"
            podman tag "$full_tag" "$new_tag" || die 11 "Failed to tag image $full_tag as $new_tag"
        fi
        podman push "$new_tag" "$registry_image_name" || die 12 "Failed to push image $new_tag to $registry_image_name"
    else
        debug "Tagging %s as %s\n" "$full_tag" "$registry_image_name"
        docker tag "$full_tag" "$registry_image_name" || die 13 "Failed to tag image $full_tag as $registry_image_name"
        docker push "$registry_image_name" || die 14 "Failed to push image $new_tag to $registry_image_name"
    fi
done

# vim: set foldmethod=marker et ts=4 sts=4 sw=4 ft=bash :
