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

`Source/APCpp/lib/Linux` is therefore built with the same toolchain Unreal uses.

## Toolchain

Satisfactory 1.2 runs on UE 5.6.1-CSS, whose Linux toolchain is
`v25_clang-18.1.0-rockylinux8`. Epic hosts it publicly:

```bash
curl -O https://cdn.unrealengine.com/Toolchain_Linux/native-linux-v25_clang-18.1.0-rockylinux8.tar.gz
tar xzf native-linux-v25_clang-18.1.0-rockylinux8.tar.gz
export UE_LINUX_TOOLCHAIN=$PWD/v25_clang-18.1.0-rockylinux8
```

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
staged archives. It needs only the toolchain, so it catches a stale or partial
`lib/Linux` without a full engine build.

## Packaging

Building the mod itself still needs the modding environment: the engine is
private and access goes through linking a GitHub account to an Epic Games
account. See the
[Linux setup guide](https://docs.ficsit.app/satisfactory-modding/latest/Development/Linux/LinuxSetup.html).

With the environment in place, select `Shipping_Server` and `Linux`, or use
Alpakit's Linux Server target.
