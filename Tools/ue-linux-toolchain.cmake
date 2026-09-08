# Builds against the same toolchain Unreal uses for its Linux targets, so the
# static libraries are ABI-compatible with the engine.
#
# Satisfactory 1.2 runs on UE 5.6.1-CSS, whose Linux toolchain is
# v25_clang-18.1.0-rockylinux8. The engine compiles with its own libc++
# (Engine/Source/ThirdParty/Unix/LibCxx), not the system libstdc++, and APCpp
# exposes std::string and std::vector across its API, so anything built with
# libstdc++ fails to link into the mod.

if(NOT UE_LINUX_TOOLCHAIN)
    set(UE_LINUX_TOOLCHAIN "$ENV{UE_LINUX_TOOLCHAIN}")
endif()
if(NOT UE_LINUX_TOOLCHAIN)
    message(FATAL_ERROR "Set UE_LINUX_TOOLCHAIN to an unpacked v25_clang-18.1.0-rockylinux8 directory")
endif()

set(UE_TARGET_TRIPLE "x86_64-unknown-linux-gnu")
set(UE_TOOLCHAIN_ROOT "${UE_LINUX_TOOLCHAIN}/${UE_TARGET_TRIPLE}")

if(NOT EXISTS "${UE_TOOLCHAIN_ROOT}/bin/clang++")
    message(FATAL_ERROR "No clang++ under ${UE_TOOLCHAIN_ROOT}/bin")
endif()

set(CMAKE_C_COMPILER "${UE_TOOLCHAIN_ROOT}/bin/clang")
set(CMAKE_CXX_COMPILER "${UE_TOOLCHAIN_ROOT}/bin/clang++")
set(CMAKE_AR "${UE_TOOLCHAIN_ROOT}/bin/llvm-ar" CACHE FILEPATH "")
set(CMAKE_RANLIB "${UE_TOOLCHAIN_ROOT}/bin/llvm-ranlib" CACHE FILEPATH "")
set(CMAKE_SYSROOT "${UE_TOOLCHAIN_ROOT}")

# Without this, find_package picks up the host distro's headers and libraries,
# which are built against a different glibc than the sysroot.
set(CMAKE_FIND_ROOT_PATH "${UE_TOOLCHAIN_ROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(UE_COMMON_FLAGS "--target=${UE_TARGET_TRIPLE} -fPIC -fvisibility=hidden")

set(CMAKE_C_FLAGS_INIT "${UE_COMMON_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT "${UE_COMMON_FLAGS} -nostdinc++ -isystem ${UE_TOOLCHAIN_ROOT}/include/c++/v1")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-fuse-ld=lld -stdlib=libc++")
