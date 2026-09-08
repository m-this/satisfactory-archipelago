# Building for the Linux dedicated server

Satisfactory has no native Linux client. On Linux desktops the game runs under
Proton, which runs the Win64 build of this mod as-is. The target that actually
needs a Linux build is the dedicated server.

## Why the Win64 libraries are not enough

`Source/APCpp/lib/Win64` holds prebuilt static libraries. Unreal compiles its
Linux targets with its own libc++, not the system libstdc++, and APCpp passes
`std::string`, `std::vector` and `std::function` across its API. A library built
with libstdc++ mangles those types differently and will not link, which is why
APCpp's own CI produces Linux artifacts that are useless here.

`Source/APCpp/lib/Linux` is therefore built with the same compiler and standard
library the engine uses.

## Toolchain

Everything is derived from the engine, so the only input is `UNREAL_ENGINE_DIR`,
pointing at the folder that contains `Engine/`:

```bash
export UNREAL_ENGINE_DIR=/path/to/UnrealEngineCSS
```

Do not substitute the standalone `v25_clang-18.1.0-rockylinux8` toolchain from
Epic's CDN. Its clang is the right one, byte for byte, but it carries libc++
18.1.0 while 5.6.1-CSS compiles against libc++ 19.1.7 from
`Engine/Source/ThirdParty/Unix/LibCxx`. The engine ships the same clang under
`Engine/Extras/ThirdPartyNotUE/SDKs/HostLinux/Linux_x64`, so taking both from
the engine keeps them from drifting apart.

## APCpp

The mod calls three entry points that no public APCpp commit contains:

- `AP_Send`, a public wrapper over the internal `APSend`
- `AP_SetPackageReceivedCallback`, fired per parsed packet with its raw JSON
- `AP_GetAllPlayers` returning `std::vector<AP_NetworkPlayer>` rather than
  `std::vector<std::pair<int,std::string>>`

`Source/APCpp/inc` was vendored from an APCpp tree that was never pushed, so the
Win64 libraries cannot be reproduced from source either. The fork at
`https://github.com/m-this/APCpp` branch `satisfactory-linux` adds those three
against the public `Satisfactory` branch.

The `AP_GetAllPlayers` return type matters more than it looks. C++ does not
mangle return types, so a mismatch links cleanly and then corrupts memory at
runtime. `Tools/build-apcpp-linux.sh` fails if the fork's
`Archipelago_Satisfactory.h` stops matching `Source/APCpp/inc`.

## Build

```bash
./Tools/build-apcpp-linux.sh
./Tools/check-apcpp-linux-link.sh
```

The first builds APCpp, IXWebSocket, jsoncpp, zlib and mbedtls and stages them
into `Source/APCpp/lib/Linux`. zlib, jsoncpp and mbedtls are bundled rather than
taken from the host so the mod does not depend on libraries the dedicated server
image may not ship, matching what `lib/Win64` does.

The second links every `AP_` function `Source/Archipelago` calls against the
staged archives, using the engine's own libc++, so it catches a stale or partial
`lib/Linux` without packaging the mod.

To confirm the archives agree with the engine's standard library, check that
every libc++ symbol they reference is one the engine defines:

```bash
UELIB=$UNREAL_ENGINE_DIR/Engine/Source/ThirdParty/Unix/LibCxx/lib/Unix/x86_64-unknown-linux-gnu
cd Source/APCpp/lib/Linux
nm -u *.a mbedtls/*.a | grep -oE '_ZN?K?St3__1[A-Za-z0-9_]+' | sort -u > /tmp/need
nm --defined-only $UELIB/libc++.a $UELIB/libc++abi.a | grep -oE '_ZN?K?St3__1[A-Za-z0-9_]+' | sort -u > /tmp/have
comm -23 /tmp/need /tmp/have
```

That last command printing nothing is the result you want.

## Packaging

Packaging needs the full modding environment: the engine is private and access
goes through linking a GitHub account to an Epic Games account, and the Wwise
SDK needs an Audiokinetic account. See the
[Linux setup guide](https://docs.ficsit.app/satisfactory-modding/latest/Development/Linux/LinuxSetup.html).

Take the Wwise download command from that guide as written. Trimming its filters
looks safe and is not: dropping the Windows platforms makes `integrate-ue` fail
on a missing `x64_vc160`, and dropping the empty `--filter DeploymentPlatforms=`
leaves out the platform-agnostic SDK headers, so the build fails on a missing
`AkWwiseSDKVersion.h`.

With the environment in place:

```bash
export UNREAL_ENGINE_DIR=/path/to/UnrealEngineCSS
export SATISFACTORY_PROJECT_DIR=/path/to/StarterProject
./Tools/package-linux-server.sh
```

That builds the editor target, which the cook step needs, then runs Alpakit's
`PackagePlugin` for the Linux server and writes the zip to
`$SATISFACTORY_PROJECT_DIR/Saved/ArchivedPlugins/Archipelago/`.

## Releases

`.github/workflows/release.yml` runs the same script on a tag push and attaches
the zip to the GitHub release.

It needs a **self-hosted runner**. The engine and the Wwise SDK are over 40 GB
together and both are access-gated, which rules out a GitHub-hosted runner. Set
two repository variables so the workflow can find them:

- `UNREAL_ENGINE_DIR`
- `SATISFACTORY_PROJECT_DIR`
