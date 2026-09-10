#!/usr/bin/env bash
# Runs Tools/apcpp-runtime-check.cpp against Source/APCpp/lib/Linux.
#
# check-apcpp-linux-link.sh only proves the entry points resolve; a library that
# faults on its first call still links clean. This one connects, polls and shuts
# down the way AApSubsystem does, so a crash inside APCpp shows up here instead
# of on someone's server. It uses an unroutable address by default so it never
# depends on a real Archipelago server: the connection failure path is what the
# dedicated server hits most often anyway.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
lib_dir=$repo_root/Source/APCpp/lib/Linux
uri=${1:-127.0.0.1:1}
seconds_max=${2:-6}

if [[ -z ${UNREAL_ENGINE_DIR:-} ]]; then
    echo "Set UNREAL_ENGINE_DIR to the folder containing Engine/." >&2
    exit 1
fi

triple=x86_64-unknown-linux-gnu
libcxx=$UNREAL_ENGINE_DIR/Engine/Source/ThirdParty/Unix/LibCxx

toolchain=${UE_LINUX_TOOLCHAIN:-}
if [[ -z $toolchain ]]; then
    for candidate in "$UNREAL_ENGINE_DIR"/Engine/Extras/ThirdPartyNotUE/SDKs/HostLinux/Linux_x64/*; do
        if [[ -x $candidate/$triple/bin/clang++ ]]; then
            toolchain=$candidate
            break
        fi
    done
fi
if [[ -z $toolchain ]]; then
    echo "No clang toolchain under $UNREAL_ENGINE_DIR/Engine/Extras/ThirdPartyNotUE/SDKs" >&2
    exit 1
fi

sysroot=$toolchain/$triple
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

"$sysroot/bin/clang++" \
    --target=$triple \
    --sysroot="$sysroot" \
    -nostdinc++ -isystem "$libcxx/include/c++/v1" \
    -nostdlib++ -fuse-ld=lld \
    -std=c++20 -g \
    -I"$repo_root/Source/APCpp/inc" \
    "$repo_root/Tools/apcpp-runtime-check.cpp" \
    -o "$out/runtime-check" \
    "$lib_dir"/*.a "$lib_dir"/mbedtls/*.a \
    -L"$libcxx/lib/Unix/$triple" -lc++ -lc++abi -lpthread

if ! "$out/runtime-check" "$uri" Satisfactory "" "$((seconds_max * 2))"; then
    status=$?
    echo >&2
    echo "apcpp-runtime-check exited $status against $uri" >&2
    exit 1
fi

echo "APCpp connects, polls and shuts down without faulting against $uri"
