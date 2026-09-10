#!/usr/bin/env bash
# Checks the packaged Linux server module against a real dedicated server.
#
# The mod links against FactoryGame, and the headers in the starter project can
# declare functions the shipped server no longer exports. That mismatch links
# fine and only shows up at load time, as
#   Plugin 'Archipelago' failed to load because module 'Archipelago' could not
#   be loaded
# so it has to be caught against the server binaries rather than at build time.
#
# Install the server with:
#   steamcmd +force_install_dir <dir> +login anonymous +app_update 1690800 validate +quit
set -euo pipefail

if [[ -z ${SATISFACTORY_SERVER_DIR:-} ]]; then
    echo "Set SATISFACTORY_SERVER_DIR to a Satisfactory dedicated server install." >&2
    exit 1
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
module=${1:-}
if [[ -z $module ]]; then
    # -print -quit rather than piping to head: head closing the pipe early kills
    # find with SIGPIPE, and pipefail then aborts this script before it checks a
    # single symbol, silently, which is the last thing a release gate should do.
    module=$(find "$repo_root" /home/*/projects -name 'libFactoryServer-Archipelago-Linux-Shipping.so' -print -quit 2>/dev/null)
fi
if [[ ! -f $module ]]; then
    echo "Pass the built libFactoryServer-Archipelago-Linux-Shipping.so as the first argument." >&2
    exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

nm -D -u "$module" | awk '{print $NF}' | sort -u > "$work/needed"

# SML and the dependency mods export a large part of what the module calls, and
# they are not in the server install, so point SATISFACTORY_MODS_DIR at a folder
# holding their unpacked LinuxServer builds. Without it every SML and ContentLib
# symbol is reported and the handful of real ones get lost in the noise.
search_dirs=("$SATISFACTORY_SERVER_DIR")
if [[ -n ${SATISFACTORY_MODS_DIR:-} ]]; then
    search_dirs+=("$SATISFACTORY_MODS_DIR")
fi

# nm exits non-zero on any file it cannot read, which xargs turns into 123, so
# the failure is swallowed rather than aborting the scan.
{ find "${search_dirs[@]}" -name '*.so' -print0 \
    | xargs -0 -n 20 nm -D --defined-only 2>/dev/null || true; } \
    | awk '{print $NF}' | sort -u > "$work/provided"

# glibc, libgcc and the C++ ABI resolve from the system, not from game modules.
comm -23 "$work/needed" "$work/provided" \
    | grep -vE '@GLIBC|@GCC|@CXXABI|^_ITM_|^__gmon_start__' > "$work/missing" || true

count=$(wc -l < "$work/missing")
if [[ $count -eq 0 ]]; then
    echo "Every symbol the module needs is exported by the server and the mods it depends on"
    exit 0
fi

echo "$count symbol(s) the server does not export, so the module will fail to load:" >&2
c++filt < "$work/missing" >&2
exit 1
