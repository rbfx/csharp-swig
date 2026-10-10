# C# samples. They use the managed Urho3DNet assemblies of this repository.
if (NOT URHO3DNET_BUILD_SAMPLES)
    return ()
endif ()

set(CMAKE_INSTALL_DEFAULT_COMPONENT_NAME Samples)

add_subdirectory(102_CSharpProject)
add_subdirectory(104_CSharpPlugin)
