# Managed host for the Player application. It needs PlayerLibrary from the engine (URHO3D_PLAYER=ON).
if (NOT TARGET PlayerLibrary)
    message(STATUS "Target PlayerLibrary not found, skipping libPlayer and the managed Player host.")
    return ()
endif ()

# Native part: a library with the CreateApplication entry point, loaded by the managed host.
# It is SHARED, not MODULE: MODULE gets the .so suffix on macOS and DllImport("libPlayer") does not find it there.
add_library (libPlayer SHARED PlayerHost.cpp)
set_target_properties(libPlayer PROPERTIES PREFIX "")
target_link_libraries(libPlayer PUBLIC PlayerLibrary)
if (COMMAND target_link_plugins)
    target_link_plugins(libPlayer "${URHO3D_PLUGIN_LIST}")
endif ()

# Managed part: an executable that hosts the .net runtime and loads libPlayer.
if (TARGET Player)
    message(FATAL_ERROR "The target Player exists already. The native Player executable of the engine has the same "
        "name as the managed Player target. Configure the engine with URHO3D_NO_EDITOR_PLAYER_EXE=ON.")
endif ()
add_target_csharp(
    TARGET Player
    EXE
    PROJECT ${CMAKE_CURRENT_SOURCE_DIR}/ManagedHost/Player.csproj
    OUTPUT ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR}/Player
    DEPENDS Urho3DNet)
if (TARGET Player)
    add_dependencies(Player libPlayer)
    if (TARGET Urho3DNet)
        add_dependencies(Player Urho3DNet)
    endif ()
endif ()
install(FILES "${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR}/Player${CMAKE_EXECUTABLE_SUFFIX}" DESTINATION ${CMAKE_INSTALL_BINDIR})
install(TARGETS libPlayer LIBRARY DESTINATION ${CMAKE_INSTALL_BINDIR} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
