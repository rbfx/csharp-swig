cmake_minimum_required(VERSION 3.25)
project(rbfx-csharp)

set(CMAKE_CXX_STANDARD 17)

# The C# bindings need these engine features.
set(URHO3D_SCRIPT_RUNTIME ON CACHE BOOL "" FORCE)
set(URHO3D_MONOLITHIC_HEADER ON CACHE BOOL "" FORCE)
# The native Player executable of the engine has the same name as the managed Player target.
set(URHO3D_NO_EDITOR_PLAYER_EXE ON CACHE BOOL "" FORCE)
if (NOT DEFINED BUILD_SHARED_LIBS)
    set(BUILD_SHARED_LIBS ON CACHE BOOL "Build shared libraries")
endif ()

# Set Urho3D_DIR to the directory with the engine package config.
# For an in-tree engine: <engine>/CMake/Urho3D/share/Urho3D
# The engine can be present already when a project adds this repository with find_package(Urho3DNet).
if (NOT TARGET Urho3D)
    find_package(Urho3D REQUIRED)
endif ()

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/CMake/Modules)
include(Urho3DNetCommon)

urho3dnet_engine_has_define(ENGINE_HAS_SCRIPT_RUNTIME URHO3D_SCRIPT_RUNTIME)
if (NOT ENGINE_HAS_SCRIPT_RUNTIME)
    message(FATAL_ERROR "The Urho3D target does not define URHO3D_SCRIPT_RUNTIME. "
        "Build the engine with URHO3D_SCRIPT_RUNTIME=ON. The C# bindings need it.")
endif ()

# Launcher for managed executables on Linux. It sets the glibc tunables that libUrho3D.so needs.
# It is next to the managed executables in the build directory and in the install directory.
if (LINUX)
    # CMAKE_INSTALL_BINDIR contains $<CONFIG> in a multi-config build, but configure_file does not expand
    # generator expressions. Copy the script one time for each configuration. configure_file keeps the permissions.
    if (CMAKE_CONFIGURATION_TYPES)
        foreach (config ${CMAKE_CONFIGURATION_TYPES})
            string(REPLACE "$<CONFIG>" "${config}" run_dotnet_dir "${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR}")
            configure_file(${CMAKE_CURRENT_LIST_DIR}/script/run-dotnet.sh ${run_dotnet_dir}/run-dotnet.sh COPYONLY)
        endforeach ()
    else ()
        configure_file(${CMAKE_CURRENT_LIST_DIR}/script/run-dotnet.sh
            ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR}/run-dotnet.sh COPYONLY)
    endif ()
    install(PROGRAMS ${CMAKE_CURRENT_LIST_DIR}/script/run-dotnet.sh DESTINATION ${CMAKE_INSTALL_BINDIR})
endif ()

# The .csproj files use the binary directory of this repository to find generated code.
# The cache keeps the value visible in a project that adds this repository with add_subdirectory.
set(Urho3DNet_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR} CACHE INTERNAL "Binary directory of the C# bindings")

add_subdirectory(ThirdParty)
add_subdirectory(Source)

if (NOT CMAKE_VS_MSBUILD_COMMAND)
    # Generate a VS solution for C# projects when outside of visual studio.
    vs_generate_sln(${CMAKE_BINARY_DIR}/${CMAKE_PROJECT_NAME}.sln ${RBFX_CSPROJ_LIST})

    if (LINUX)
        # On linux instance of dotnet may hang indefinitely which prevents CMake from detecting build completion.
        set (DOTNET_LINUX_MSBUILD_WORKAROUND COMMAND ${CMAKE_CURRENT_LIST_DIR}/script/.kill_dangling_dotnet.sh ${DOTNET})
    elseif ("${CMAKE_GENERATOR}" MATCHES "^Xcode")
        # On MacOS Xcode pollutes environment which causes MSBuild to compile all managed targets into one assembly.
        set (DOTNET_MACOS_MSBUILD_WORKAROUND env -u TARGET_NAME -u TARGETNAME)
    endif ()
    add_custom_target(BuildManagedTargets ALL
        COMMAND ${DOTNET_MACOS_MSBUILD_WORKAROUND} ${DOTNET} build ${CMAKE_BINARY_DIR}/${CMAKE_PROJECT_NAME}.sln
            -restore -noLogo -interactive:false -nr:false -p:CMAKE_BINARY_DIR=${CMAKE_BINARY_DIR}/
            -consoleLoggerParameters:ErrorsOnly -p:Platform=${URHO3D_PLATFORM} -p:Configuration=${URHO3D_CONFIG}
            ${DOTNET_LINUX_MSBUILD_WORKAROUND}
        DEPENDS Urho3DCSharp COMMAND_EXPAND_LISTS)
    foreach (TARGET libEditorWrapper libPlayer Urho3DNetTestsLib)
        if (TARGET ${TARGET})
            add_dependencies(BuildManagedTargets ${TARGET})
        endif ()
    endforeach ()
endif ()

# Install the CMake package: find_package(Urho3DNet) in the SDK form.
# The export file Urho3DNet.cmake is installed by Source/Urho3DNet/CMakeLists.txt.
set(Urho3DNet_CMAKE_INSTALL_DIR ${CMAKE_INSTALL_DATADIR}/Urho3DNet/CMake)
include(CMakePackageConfigHelpers)
configure_package_config_file(
    ${CMAKE_CURRENT_LIST_DIR}/CMake/Urho3DNetConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/Urho3DNetConfig.cmake
    INSTALL_DESTINATION ${Urho3DNet_CMAKE_INSTALL_DIR}
)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/Urho3DNetConfig.cmake DESTINATION ${Urho3DNet_CMAKE_INSTALL_DIR})
install(FILES
    ${Urho3DNet_SOURCE_DIR}/CMake/Modules/Urho3DNetCommon.cmake
    ${Urho3DNet_SOURCE_DIR}/CMake/Modules/VSSolution.cmake
    DESTINATION ${Urho3DNet_CMAKE_INSTALL_DIR}/Modules)
# Projects of the consumer import this file through URHO3D_CSHARP_PROPS_FILE.
install(FILES ${Urho3DNet_SOURCE_DIR}/Directory.Build.props DESTINATION ${Urho3DNet_CMAKE_INSTALL_DIR})

rbfx_configure_cmake_props()
