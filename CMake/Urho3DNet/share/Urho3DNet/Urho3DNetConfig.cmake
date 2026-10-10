# Copyright (c) 2025-2026 the rbfx project.
# This work is licensed under the terms of the MIT license.
# For a copy, see <https:#opensource.org/licenses/MIT> or the accompanying LICENSE file.

# This is a dummy package configuration file for Urho3DNet. It allows a project to use the C# bindings
# through an in-source build (add_subdirectory) with the same find_package() call as the installed SDK.
# Set Urho3DNet_DIR to the directory of this file.

# Source root directory
get_filename_component(Urho3DNet_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../.." ABSOLUTE)

# The bindings need the engine.
if (NOT TARGET Urho3D)
    find_package(Urho3D REQUIRED)
endif ()

# Include the bindings as in-source build
add_subdirectory(${Urho3DNet_ROOT} ${CMAKE_BINARY_DIR}/rbfx-csharp)

# Make the modules accessible
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${Urho3DNet_ROOT}/CMake/Modules)

# Include common functionality. It sets Urho3DNet_SOURCE_DIR and the tool paths.
include(Urho3DNetCommon)

# Mark Urho3DNet as found
set(Urho3DNet_FOUND TRUE)
