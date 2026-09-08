#!/usr/bin/env bash
# Links Tools/apcpp-link-check.cpp against Source/APCpp/lib/Linux.
#
# Catches a stale or partial lib/Linux without packaging the mod. Libraries are
# passed in the order APCpp.Build.cs adds them, so this also covers link order,
# which GNU ld cares about and MSVC does not.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
lib_dir=$repo_root/Source/APCpp/lib/Linux

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
    -std=c++20 \
    -I"$repo_root/Source/APCpp/inc" \
    "$repo_root/Tools/apcpp-link-check.cpp" \
    -o "$out/link-check" \
    "$lib_dir"/*.a "$lib_dir"/mbedtls/*.a \
    -L"$libcxx/lib/Unix/$triple" -lc++ -lc++abi -lpthread

echo "Every AP_ entry point the mod calls resolves against $lib_dir"
