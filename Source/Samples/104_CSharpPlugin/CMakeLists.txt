# Copyright (c) 2017-2026 the rbfx project.
# This work is licensed under the terms of the MIT license.
# For a copy, see <https:#opensource.org/licenses/MIT> or the accompanying LICENSE file.

# The plugin needs engine plugin support and a player that loads it.
urho3dnet_engine_has_define(ENGINE_HAS_PLUGINS URHO3D_PLUGINS)
if (NOT ENGINE_HAS_PLUGINS OR NOT TARGET PlayerLibrary)
    return ()
endif ()

add_target_csharp(
    TARGET 104_CSharpPlugin
    PROJECT ${CMAKE_CURRENT_SOURCE_DIR}/104_CSharpPlugin.csproj
    OUTPUT ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR}/104_CSharpPlugin
    DEPENDS Urho3DNet)
install (FILES ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR}/104_CSharpPlugin.dll DESTINATION ${CMAKE_INSTALL_BINDIR})
