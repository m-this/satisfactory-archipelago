#!/usr/bin/env bash
# Builds and packages the mod for the Linux dedicated server.
#
# Produces Saved/ArchivedPlugins/Archipelago/*.zip in the starter project, which
# is the layout Satisfactory Mod Manager and ficsit.app install from.
set -euo pipefail

if [[ -z ${UNREAL_ENGINE_DIR:-} ]]; then
    echo "Set UNREAL_ENGINE_DIR to the folder containing Engine/." >&2
    exit 1
fi
if [[ -z ${SATISFACTORY_PROJECT_DIR:-} ]]; then
    echo "Set SATISFACTORY_PROJECT_DIR to a starter project with Wwise integrated." >&2
    exit 1
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
uproject=$SATISFACTORY_PROJECT_DIR/FactoryGame.uproject
mod_link=$SATISFACTORY_PROJECT_DIR/Mods/Archipelago

if [[ ! -f $uproject ]]; then
    echo "No FactoryGame.uproject under $SATISFACTORY_PROJECT_DIR" >&2
    exit 1
fi

# Both are cheap and both catch a package that installs and then misbehaves at
# runtime, which is the failure mode this port keeps producing.
"$repo_root/Tools/check-contentlib-eol.sh"
"$repo_root/Tools/check-apcpp-linux-runtime.sh"

# The project builds the mod from Mods/, so point that at this checkout rather
# than keeping a second copy of the sources.
if [[ ! -e $mod_link ]] || [[ $(readlink -f "$mod_link") != "$repo_root" ]]; then
    ln -sfn "$repo_root" "$mod_link"
fi

# While paking, zen raises the descriptor limit to its own maximum, which fails
# when that is above fs.nr_open. Go to the hard limit instead of a fixed number,
# which a plain `ulimit -n 1048576` cannot do when the hard limit sits lower.
ulimit -n "$(ulimit -Hn)"

# The cook step runs in the editor, so that target has to exist first.
"$UNREAL_ENGINE_DIR/Engine/Build/BatchFiles/Linux/Build.sh" \
    FactoryEditor Linux Development -project="$uproject"

"$UNREAL_ENGINE_DIR/Engine/Build/BatchFiles/Linux/Build.sh" \
    FactoryServer Linux Shipping -project="$uproject"

# Both targets are built above, so PackagePlugin only cooks, stages and zips.
# Letting it build would pull in FactoryGameEGS and FactoryGameSteam, and the
# engine rejects game targets for Linux because Satisfactory has no Linux client.
"$UNREAL_ENGINE_DIR/Engine/Build/BatchFiles/RunUAT.sh" \
    -ScriptsForProject="$uproject" PackagePlugin \
    -Project="$uproject" \
    -dlcname=Archipelago \
    -merge -server \
    -serverconfig=Shipping \
    -serverplatform=Linux \
    -noclient \
    -nocompileeditor -installed

echo
echo "Packaged:"
ls -1 "$SATISFACTORY_PROJECT_DIR/Saved/ArchivedPlugins/Archipelago/"*.zip
