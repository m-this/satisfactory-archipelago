# Builds against the exact compiler and standard library Unreal uses for its
# Linux targets, so the static libraries are ABI-compatible with the engine.
#
# Everything is derived from the engine rather than from a separately downloaded
# toolchain, because the two do not agree: the bundled toolchain carries libc++
# 18.1.0, while the engine compiles with its own libc++ under
# Engine/Source/ThirdParty/Unix/LibCxx, which is 19.1.7 on 5.6.1-CSS. APCpp
# exposes std::string, std::vector and std::function across its API, so building
# against the wrong headers is exactly the mismatch that has to be avoided.

if(NOT UNREAL_ENGINE_DIR)
    set(UNREAL_ENGINE_DIR "$ENV{UNREAL_ENGINE_DIR}")
endif()
if(NOT UNREAL_ENGINE_DIR)
    message(FATAL_ERROR "Set UNREAL_ENGINE_DIR to the folder containing Engine/")
endif()

set(UE_TARGET_TRIPLE "x86_64-unknown-linux-gnu")
set(UE_LIBCXX_DIR "${UNREAL_ENGINE_DIR}/Engine/Source/ThirdParty/Unix/LibCxx")

if(NOT EXISTS "${UE_LIBCXX_DIR}/include/c++/v1/__config")
    message(FATAL_ERROR "No libc++ headers under ${UE_LIBCXX_DIR}")
endif()

# The engine ships the clang it was built with; prefer it over anything on PATH.
if(NOT UE_LINUX_TOOLCHAIN)
    set(UE_LINUX_TOOLCHAIN "$ENV{UE_LINUX_TOOLCHAIN}")
endif()
if(NOT UE_LINUX_TOOLCHAIN)
    file(GLOB _sdk_candidates
        "${UNREAL_ENGINE_DIR}/Engine/Extras/ThirdPartyNotUE/SDKs/HostLinux/Linux_x64/*")
    foreach(_candidate ${_sdk_candidates})
        if(EXISTS "${_candidate}/${UE_TARGET_TRIPLE}/bin/clang++")
            set(UE_LINUX_TOOLCHAIN "${_candidate}")
            break()
        endif()
    endforeach()
endif()
if(NOT UE_LINUX_TOOLCHAIN)
    message(FATAL_ERROR "No clang toolchain under ${UNREAL_ENGINE_DIR}/Engine/Extras/ThirdPartyNotUE/SDKs")
endif()

set(UE_TOOLCHAIN_ROOT "${UE_LINUX_TOOLCHAIN}/${UE_TARGET_TRIPLE}")

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
set(CMAKE_CXX_FLAGS_INIT "${UE_COMMON_FLAGS} -nostdinc++ -isystem ${UE_LIBCXX_DIR}/include/c++/v1")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-fuse-ld=lld -nostdlib++ -L${UE_LIBCXX_DIR}/lib/Unix/${UE_TARGET_TRIPLE} -lc++ -lc++abi")
