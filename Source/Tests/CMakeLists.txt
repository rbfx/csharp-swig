# Copyright (c) 2017-2026 the rbfx project.
# This work is licensed under the terms of the MIT license.
# For a copy, see <https:#opensource.org/licenses/MIT> or the accompanying LICENSE file.

if (NOT URHO3DNET_BUILD_TESTS)
    return ()
endif ()

# Native library of the managed tests. It contains only the native helpers declared in TestBindings.i,
# the SWIG wrappers of the helpers are the only source file. The engine code comes from Urho3DCSharp.
add_library(Urho3DNetTestsLib SHARED)
target_link_libraries(Urho3DNetTestsLib PRIVATE Urho3DCSharp)

csharp_bind_target(
    TARGET Urho3DNetTestsLib
    SWIG ${CMAKE_CURRENT_SOURCE_DIR}/CSharp/TestBindings.i
    CSPROJ ${CMAKE_CURRENT_SOURCE_DIR}/CSharp/Urho3DNet.Tests.csproj
    NAMESPACE Urho3DNet
    DEPENDS Urho3DCSharp
)
if (TARGET Urho3DNet.Tests)
    add_dependencies(Urho3DNet.Tests Urho3DNet)
endif ()
