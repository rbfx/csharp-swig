# Managed host for the Editor application. It needs EditorLibrary from the engine (URHO3D_EDITOR=ON).
if (NOT TARGET EditorLibrary)
    message(STATUS "Target EditorLibrary not found, skipping libEditorWrapper and EditorManaged.")
    return ()
endif ()

# Native part: a shared library with the CreateApplication entry point, loaded by the managed host.
add_library (libEditorWrapper SHARED EditorWrapper.cpp)
set_target_properties(libEditorWrapper PROPERTIES PREFIX "")
target_link_libraries (libEditorWrapper PUBLIC EditorLibrary)
if (COMMAND target_link_plugins)
    target_link_plugins(libEditorWrapper "${URHO3D_PLUGIN_LIST}")
endif ()

# Managed part: an executable that hosts the .net runtime and loads the editor.
add_target_csharp(
    TARGET EditorManaged
    EXE
    PROJECT ${CMAKE_CURRENT_SOURCE_DIR}/EditorManaged/EditorManaged.csproj
    OUTPUT ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR}/EditorManaged
    DEPENDS Urho3DNet)
if (TARGET EditorManaged)
    add_dependencies(EditorManaged libEditorWrapper)
    if (TARGET Urho3DNet)
        add_dependencies(EditorManaged Urho3DNet)
    endif ()
endif ()
install(PROGRAMS "${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR}/EditorManaged${CMAKE_EXECUTABLE_SUFFIX}"
    DESTINATION ${CMAKE_INSTALL_BINDIR})
install(TARGETS libEditorWrapper LIBRARY DESTINATION ${CMAKE_INSTALL_BINDIR} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
