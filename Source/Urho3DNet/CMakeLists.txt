# Native part of the C# bindings: SWIG wrappers and native helpers.
file (GLOB_RECURSE NATIVE_HEADERS ${CMAKE_CURRENT_SOURCE_DIR}/Native/*.h)
file (GLOB_RECURSE NATIVE_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/Native/*.cpp)

add_library(Urho3DCSharp SHARED ${NATIVE_HEADERS} ${NATIVE_SOURCES})
target_link_libraries(Urho3DCSharp PUBLIC Urho3D)

# Users can import Urho3D.i in their bindings .i
# Headers are included as <Urho3DNet/Native/SWIGHelpers.h>, so Source/ is the include root.
target_include_directories(Urho3DCSharp PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/Swig>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/Native>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/Urho3DNet/Swig>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/Urho3DNet/Native>
)

if (MSVC)
    target_compile_options(Urho3DCSharp PRIVATE /bigobj)
endif ()

csharp_bind_target(
    TARGET Urho3D
    EMBED Urho3DCSharp
    SWIG ${CMAKE_CURRENT_SOURCE_DIR}/Swig/Urho3D.i
    CSPROJ ${CMAKE_CURRENT_SOURCE_DIR}/Urho3DNet.csproj
    NAMESPACE Urho3DNet
)

urho3dnet_engine_has_define(ENGINE_HAS_SYSTEMUI URHO3D_SYSTEMUI)
if (ENGINE_HAS_SYSTEMUI)
    csharp_bind_target(
        TARGET ImGui
        EMBED Urho3DCSharp
        SWIG ${CMAKE_CURRENT_SOURCE_DIR}/Swig/ImGui.i
        NAMESPACE ImGuiNet
    )
endif ()

add_target_csharp(
    TARGET Urho3DNet.Scripts
    PROJECT ${CMAKE_CURRENT_SOURCE_DIR}/Urho3DNet.Scripts.csproj
    OUTPUT ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR}/Urho3DNet.Scripts
    DEPENDS Urho3DNet
)

add_target_csharp(
    TARGET Urho3DNet.CodeGenerator
    PROJECT ${CMAKE_CURRENT_SOURCE_DIR}/Urho3DNet.CodeGenerator.csproj
    OUTPUT ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR}/Urho3DNet.CodeGenerator
)

# Install rules. SWIG interface files and native headers go to include/Urho3DNet.
install (DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/Swig DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/Urho3DNet)
install (FILES ${NATIVE_HEADERS} DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/Urho3DNet/Native)
install (TARGETS Urho3DCSharp
    EXPORT Urho3DNet
    LIBRARY DESTINATION ${CMAKE_INSTALL_BINDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
# Install the managed assemblies that C# builds produce. CMake does not know these files.
install (CODE "set (MANAGED_BINARY_DIR \"${CMAKE_BINARY_DIR}\")")
install (SCRIPT ${Urho3DNet_SOURCE_DIR}/CMake/InstallManaged.cmake)
# Export file of the package. Urho3DNetConfig.cmake includes it.
install (EXPORT Urho3DNet DESTINATION ${CMAKE_INSTALL_DATADIR}/Urho3DNet/CMake FILE Urho3DNet.cmake)
