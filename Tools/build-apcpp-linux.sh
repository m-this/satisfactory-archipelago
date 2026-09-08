#!/usr/bin/env bash
# Builds APCpp and its dependencies into Source/APCpp/lib/Linux.
#
# The mod calls AP_Send, AP_SetPackageReceivedCallback and an AP_GetAllPlayers
# overload that no public APCpp commit contains, so this pulls a fork that adds
# them. See Docs/LinuxServer.md.
set -euo pipefail

APCPP_REPO=${APCPP_REPO:-https://github.com/m-this/APCpp.git}
APCPP_REF=${APCPP_REF:-satisfactory-linux}

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work_dir=$repo_root/Build/APCpp
build_dir=$work_dir/build
lib_dir=$repo_root/Source/APCpp/lib/Linux
inc_dir=$repo_root/Source/APCpp/inc

if [[ -z ${UNREAL_ENGINE_DIR:-} ]]; then
    echo "Set UNREAL_ENGINE_DIR to the folder containing Engine/." >&2
    echo "The engine supplies both the clang Unreal builds with and the libc++ it" >&2
    echo "compiles against, which the standalone toolchain download does not match." >&2
    exit 1
fi

if [[ ! -d $work_dir/.git ]]; then
    git clone --branch "$APCPP_REF" --recurse-submodules "$APCPP_REPO" "$work_dir"
else
    git -C "$work_dir" fetch origin "$APCPP_REF"
    git -C "$work_dir" checkout --detach FETCH_HEAD
    git -C "$work_dir" submodule update --init --recursive
fi

# Bundling zlib, jsoncpp and mbedtls keeps the mod binary free of host libraries
# the dedicated server image is not guaranteed to ship, and mirrors lib/Win64.
cmake -S "$work_dir" -B "$build_dir" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$repo_root/Tools/ue-linux-toolchain.cmake" \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_MBED_TLS=ON \
    -DBUNDLED_JSONCPP=ON

cmake --build "$build_dir" --target APCpp

rm -rf "$lib_dir"
mkdir -p "$lib_dir/mbedtls"

install -m 644 "$build_dir/libAPCpp.a" "$lib_dir/libAPCpp.a"
install -m 644 "$work_dir/LICENSE" "$lib_dir/libAPCpp.a.license.txt"

install -m 644 "$build_dir/IXWebSocket/libixwebsocket.a" "$lib_dir/libixwebsocket.a"
install -m 644 "$work_dir/IXWebSocket/LICENSE.txt" "$lib_dir/libixwebsocket.a.license.txt"

install -m 644 "$build_dir/jsoncpp/src/lib_json/libjsoncpp.a" "$lib_dir/libjsoncpp.a"
install -m 644 "$work_dir/jsoncpp/LICENSE" "$lib_dir/libjsoncpp.a.license.txt"

install -m 644 "$build_dir/_deps/zlib-build/libz.a" "$lib_dir/libz.a"
install -m 644 "$work_dir/zlib/LICENSE" "$lib_dir/libz.a.license.txt"

for lib in mbedtls mbedx509 mbedcrypto everest p256m; do
    install -m 644 "$(find "$build_dir/mbedtls_bin" -name "lib$lib.a" -print -quit)" "$lib_dir/mbedtls/lib$lib.a"
done
install -m 644 "$build_dir"/mbedtls-*/LICENSE "$lib_dir/mbedtls/License for mbedtls.txt"

# inc/ is the contract the existing Win64 libraries were compiled against, so it
# is checked rather than overwritten: a mismatch here means the Linux and Windows
# builds would disagree on a signature, which links fine and corrupts memory at
# runtime because C++ does not mangle return types.
if ! diff -q --strip-trailing-cr "$work_dir/Archipelago_Satisfactory.h" "$inc_dir/Archipelago_Satisfactory.h" >/dev/null; then
    echo "$APCPP_REPO@$APCPP_REF drifted from $inc_dir/Archipelago_Satisfactory.h" >&2
    diff -u --strip-trailing-cr "$inc_dir/Archipelago_Satisfactory.h" "$work_dir/Archipelago_Satisfactory.h" >&2 || true
    exit 1
fi

echo
echo "Staged into $lib_dir:"
ls -1 "$lib_dir" "$lib_dir/mbedtls"
