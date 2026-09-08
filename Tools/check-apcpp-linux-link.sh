#!/usr/bin/env bash
# Links Tools/apcpp-link-check.cpp against Source/APCpp/lib/Linux.
#
# Catches a stale or partial lib/Linux without needing the engine. Libraries are
# passed in the order APCpp.Build.cs adds them, so this also covers link order,
# which GNU ld cares about and MSVC does not.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
lib_dir=$repo_root/Source/APCpp/lib/Linux

if [[ -z ${UE_LINUX_TOOLCHAIN:-} ]]; then
    echo "Set UE_LINUX_TOOLCHAIN to an unpacked v25_clang-18.1.0-rockylinux8 directory." >&2
    exit 1
fi

toolchain=$UE_LINUX_TOOLCHAIN/x86_64-unknown-linux-gnu
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

"$toolchain/bin/clang++" \
    --target=x86_64-unknown-linux-gnu \
    --sysroot="$toolchain" \
    -nostdinc++ -isystem "$toolchain/include/c++/v1" \
    -stdlib=libc++ -fuse-ld=lld \
    -std=c++20 \
    -I"$repo_root/Source/APCpp/inc" \
    "$repo_root/Tools/apcpp-link-check.cpp" \
    -o "$out/link-check" \
    "$lib_dir"/*.a "$lib_dir"/mbedtls/*.a -lpthread

echo "Every AP_ entry point the mod calls resolves against $lib_dir"
