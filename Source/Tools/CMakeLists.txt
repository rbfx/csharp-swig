# C# tools. They use the managed Urho3DNet assemblies of this repository.
if (NOT URHO3DNET_BUILD_TOOLS OR NOT DESKTOP)
    return ()
endif ()

set(CMAKE_INSTALL_DEFAULT_COMPONENT_NAME Tools)

add_subdirectory(ScriptPlayer)
