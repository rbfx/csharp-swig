# Common CMake functionality for the C# bindings of rbfx.
# Include this module after find_package(Urho3D REQUIRED).

include(VSSolution)

# Package form: Urho3DNetConfig.cmake sets Urho3DNet_IS_SDK and Urho3DNet_PACKAGE_ROOT before it includes this module.
# In-tree form: this module lives in the source tree of this repository.
if (Urho3DNet_IS_SDK)
    if (NOT DEFINED URHO3D_SWIG_LIB_DIR)
        set (URHO3D_SWIG_LIB_DIR ${Urho3DNet_PACKAGE_ROOT}/include/swig/Lib)
    endif ()
    set (URHO3D_CMAKE_DIR ${Urho3DNet_PACKAGE_ROOT}/share/Urho3DNet/CMake)
    set (URHO3D_CSHARP_PROPS_FILE ${URHO3D_CMAKE_DIR}/Directory.Build.props)
    if (NOT DEFINED SWIG_EXECUTABLE)
        set (SWIG_EXECUTABLE ${Urho3DNet_PACKAGE_ROOT}/share/Urho3DNet/bin/swig${CMAKE_EXECUTABLE_SUFFIX})
    endif ()
else ()
    # Root of this repository.
    get_filename_component(Urho3DNet_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

    set (URHO3D_SWIG_LIB_DIR ${Urho3DNet_SOURCE_DIR}/ThirdParty/swig/Lib)
    set (URHO3D_CMAKE_DIR ${Urho3DNet_SOURCE_DIR}/CMake)
    set (URHO3D_CSHARP_PROPS_FILE ${Urho3DNet_SOURCE_DIR}/Directory.Build.props)
endif ()

# The engine sets these variables in its own directory scope. Native libraries and managed assemblies of this
# repository must be next to the engine libraries.
if (NOT URHO3D_PLATFORM)
    include(PlatformTag)
    rbfx_get_platform_tag(URHO3DNET_PLATFORM_TAG TARGET)
    string(REPLACE "-" ";" URHO3DNET_PLATFORM_TAG_PARTS "${URHO3DNET_PLATFORM_TAG}")
    list(GET URHO3DNET_PLATFORM_TAG_PARTS 1 URHO3D_PLATFORM)
endif ()
if (NOT DEFINED CMAKE_RUNTIME_OUTPUT_DIRECTORY)
    set (CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR})
endif ()
if (NOT DEFINED CMAKE_LIBRARY_OUTPUT_DIRECTORY)
    set (CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR})
endif ()
if (NOT DEFINED CMAKE_ARCHIVE_OUTPUT_DIRECTORY)
    set (CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
endif ()

# Options of the managed projects.
# Valid values at https://docs.microsoft.com/en-us/dotnet/standard/frameworks
# At the moment only netstandard2.1 supported
set(URHO3D_NETFX netstandard2.1 CACHE STRING "TargetFramework value for .NET libraries")
set_property(CACHE URHO3D_NETFX PROPERTY STRINGS netstandard2.1)
set(URHO3D_NETFX_RUNTIME_VERSION OFF CACHE STRING "Version of runtime to use.")

# Ensure variable is in the cache.
set(RBFX_CSPROJ_LIST "" CACHE STRING "A list of C# projects." FORCE)

# Sets OUT_VAR to TRUE if target Urho3D has compile definition DEFINE_NAME or DEFINE_NAME=1.
function (urho3dnet_engine_has_define OUT_VAR DEFINE_NAME)
    set (${OUT_VAR} FALSE PARENT_SCOPE)
    if (NOT TARGET Urho3D)
        return ()
    endif ()
    get_target_property(defines Urho3D INTERFACE_COMPILE_DEFINITIONS)
    if (defines AND ("${DEFINE_NAME}" IN_LIST defines OR "${DEFINE_NAME}=1" IN_LIST defines))
        set (${OUT_VAR} TRUE PARENT_SCOPE)
    endif ()
endfunction ()

# Xcode does not support per-config source files, therefore we must lock generated bindings to some config
# and they wont switch when build config changes in Xcode.
if (CMAKE_GENERATOR STREQUAL "Xcode")
    if (CMAKE_BUILD_TYPE)
        set (URHO3D_CSHARP_BIND_CONFIG "${CMAKE_BUILD_TYPE}")
    else ()
        set (URHO3D_CSHARP_BIND_CONFIG "Release")
    endif ()
elseif (MULTI_CONFIG_PROJECT)
    set (URHO3D_CSHARP_BIND_CONFIG $<CONFIG>)
elseif (CMAKE_BUILD_TYPE)
    set (URHO3D_CSHARP_BIND_CONFIG ${CMAKE_BUILD_TYPE})
else ()
    set (URHO3D_CSHARP_BIND_CONFIG Release)
endif ()

# Generate CMake.props which will be included in .csproj files. This function should be called after all targets are
# added to the project, because it depends on target properties.
function (rbfx_configure_cmake_props)
    if (NOT PROJECT_IS_TOP_LEVEL)
        return ()
    endif ()

    cmake_parse_arguments(PROPS "" "OUT" "" ${ARGN})

    if (NOT DEFINED PROPS_OUT)
        set(PROPS_OUT "${CMAKE_BINARY_DIR}/CMake.props")
    endif ()

    file(WRITE "${PROPS_OUT}" "<Project>\n")
    file(APPEND "${PROPS_OUT}" "  <PropertyGroup>\n")
    file(APPEND "${PROPS_OUT}" "    <CMakePropsIncluded>true</CMakePropsIncluded>\n")

    # Variables of interest
    foreach (var
        CMAKE_RUNTIME_OUTPUT_DIRECTORY
        CMAKE_CONFIGURATION_TYPES
        URHO3D_CSHARP_PROPS_FILE
        URHO3D_PLATFORM
        Urho3D_IS_SDK
        Urho3D_PACKAGE_ROOT
        Urho3DNet_IS_SDK
        Urho3DNet_PACKAGE_ROOT
        URHO3D_NETFX
        URHO3D_NETFX_RUNTIME_IDENTIFIER
        URHO3D_NETFX_RUNTIME)
        string(REPLACE "$<CONFIG>" "$(Configuration)" var_value "${${var}}")
        file(APPEND "${PROPS_OUT}" "    <${var}>${var_value}</${var}>\n")
    endforeach ()

    # Urho3DNet_SOURCE_DIR and Urho3DNet_BINARY_DIR of this repository come from the loop below.
    # Urho3DNet_SOURCE_DIR is set only in the in-tree form. The .csproj files use Urho3DNet_BINARY_DIR to find
    # generated code.

    # Binary/sourece dirs
    get_cmake_property(vars VARIABLES)
    list (SORT vars)
    foreach (var ${vars})
        if ("${var}" MATCHES "_(BINARY|SOURCE)_DIR$")
            if (NOT "${${var}}" MATCHES "^.+/ThirdParty/.+$")
                string(REPLACE "." "_" var_name "${var}")
                set(var_value "${${var}}")
                string(REPLACE "$<CONFIG>" "$(Configuration)" var_value "${var_value}")
                if ("${var_value}" MATCHES "/")
                    # Paths end with /
                    if (NOT "${var_value}" MATCHES "/$")
                        set(var_value "${var_value}/")
                    endif ()
                elseif ("${var_value}" MATCHES "1|ON|YES|TRUE|Y|on|yes|true|y|On|Yes|True")
                    set(var_value "ON")
                elseif ("${var_value}" MATCHES "0|OFF|NO|FALSE|Y|off|no|false|n|Off|No|False")
                    set(var_value "OFF")
                endif ()
                file(APPEND "${PROPS_OUT}" "    <${var_name}>${var_value}</${var_name}>\n")
            endif ()
        endif ()
    endforeach()

    # C# build config, translate CMake generator expression to MSBuild expression.
    string(REPLACE "$<CONFIG>" "$(Configuration)" URHO3D_CSHARP_BIND_CONFIG_PROP "${URHO3D_CSHARP_BIND_CONFIG}")
    file(APPEND "${PROPS_OUT}" "    <URHO3D_CSHARP_BIND_CONFIG>${URHO3D_CSHARP_BIND_CONFIG_PROP}</URHO3D_CSHARP_BIND_CONFIG>\n")

    file(APPEND "${PROPS_OUT}" "  </PropertyGroup>\n")
    file(APPEND "${PROPS_OUT}" "</Project>\n")
endfunction ()

find_program(DOTNET dotnet)
if (NOT DOTNET)
    message(FATAL_ERROR "dotnet executable was not found.")
endif ()

# Detect runtime version
execute_process(COMMAND ${DOTNET} --list-sdks OUTPUT_VARIABLE DOTNET_SDKS OUTPUT_STRIP_TRAILING_WHITESPACE)
string(REGEX REPLACE "\\.[0-9]+ [^\r\n]+" "" DOTNET_SDKS "${DOTNET_SDKS}")      # Trim patch version and SDK paths
string(REGEX REPLACE "\r?\n" ";" DOTNET_SDKS "${DOTNET_SDKS}")                  # Turn lines into a list
list(REVERSE DOTNET_SDKS)                                                       # Highest version goes first
if (URHO3D_NETFX_RUNTIME_VERSION)
    string (REPLACE "." "\\." URHO3D_NETFX_RUNTIME_VERSION "${URHO3D_NETFX_RUNTIME_VERSION}")
    string (REPLACE "*" "." URHO3D_NETFX_RUNTIME_VERSION "${URHO3D_NETFX_RUNTIME_VERSION}")
    set (URHO3D_NETFX_RUNTIME_VERSION_REGEX "${URHO3D_NETFX_RUNTIME_VERSION}")
    unset (URHO3D_NETFX_RUNTIME_VERSION)
    foreach (VERSION ${DOTNET_SDKS})
        if ("${VERSION}" MATCHES "${URHO3D_NETFX_RUNTIME_VERSION_REGEX}")
            set (URHO3D_NETFX_RUNTIME_VERSION "${VERSION}")
            break ()
        endif ()
    endforeach ()
endif ()
if (NOT URHO3D_NETFX_RUNTIME_VERSION)
    list (GET DOTNET_SDKS 0 URHO3D_NETFX_RUNTIME_VERSION)
endif ()

# Trim extra elements that may be preset in version string. Eg. "6.0.100-preview.6.21355.2" is converted to "6.0".
string(REGEX REPLACE "([0-9]+)\\.([0-9]+)(.+)?" "\\1.\\2" URHO3D_NETFX_RUNTIME_VERSION "${URHO3D_NETFX_RUNTIME_VERSION}")
if (URHO3D_NETFX_RUNTIME_VERSION VERSION_LESS "5.0")
    set (NETCORE core)
endif ()
set (URHO3D_NETFX_RUNTIME "net${NETCORE}${URHO3D_NETFX_RUNTIME_VERSION}")

if (WIN32)
    set (URHO3D_NETFX_RUNTIME_IDENTIFIER win-${URHO3D_PLATFORM})
elseif (MACOS)
    set (URHO3D_NETFX_RUNTIME_IDENTIFIER osx-${URHO3D_PLATFORM})
else ()
    set (URHO3D_NETFX_RUNTIME_IDENTIFIER linux-${URHO3D_PLATFORM})
endif ()

set (DOTNET_FRAMEWORK_TYPES net6 net7)
set (DOTNET_FRAMEWORK_VERSIONS v6.0 v7.0)
list (FIND DOTNET_FRAMEWORK_TYPES ${URHO3D_NETFX} DOTNET_FRAMEWORK_INDEX)
if (DOTNET_FRAMEWORK_INDEX GREATER -1)
    list (GET DOTNET_FRAMEWORK_VERSIONS ${DOTNET_FRAMEWORK_INDEX} CMAKE_DOTNET_TARGET_FRAMEWORK_VERSION)
endif ()
unset (DOTNET_FRAMEWORK_INDEX)

# The engine UrhoCommon module (loaded by find_package(Urho3D)) provides setup_external_tool and
# __TARGET_GET_PROPERTIES_RECURSIVE. Fail early if it does not.
if (NOT COMMAND setup_external_tool OR NOT COMMAND __TARGET_GET_PROPERTIES_RECURSIVE)
    message(FATAL_ERROR "Urho3DNetCommon: setup_external_tool or __TARGET_GET_PROPERTIES_RECURSIVE is not provided by the engine.")
endif ()

function (add_target_csharp)
    cmake_parse_arguments (CS "EXE" "TARGET;PROJECT;OUTPUT" "DEPENDS" ${ARGN})
    if (MSVC)
        include_external_msproject(${CS_TARGET} ${CS_PROJECT} TYPE FAE04EC0-301F-11D3-BF4B-00C04F79EFBC ${CS_DEPENDS})
        if (CS_DEPENDS)
            add_dependencies(${CS_TARGET} ${CS_DEPENDS})
        endif ()
    else ()
        list(APPEND RBFX_CSPROJ_LIST ${CS_PROJECT})
        set(RBFX_CSPROJ_LIST "${RBFX_CSPROJ_LIST}" CACHE STRING "A list of C# projects." FORCE)
    endif ()
    install (FILES "${CS_OUTPUT}.runtimeconfig.json" DESTINATION "${CMAKE_INSTALL_BINDIR}" OPTIONAL)
    install (FILES "${CS_OUTPUT}.dll" DESTINATION "${CMAKE_INSTALL_BINDIR}" OPTIONAL)
endfunction ()

function (csharp_bind_target)
    cmake_parse_arguments(BIND "" "TARGET;CSPROJ;SWIG;NAMESPACE;EMBED;DEPENDS" "" ${ARGN})

    # General SWIG parameters
    set(BIND_OUT_DIR  ${CMAKE_CURRENT_BINARY_DIR}/${BIND_TARGET}CSharp_${URHO3D_CSHARP_BIND_CONFIG})
    set(BIND_OUT_FILE ${BIND_OUT_DIR}/${BIND_TARGET}CSHARP_wrap.cxx)
    set(GENERATOR_OPTIONS
        -csharp
        -namespace "${BIND_NAMESPACE}"
        -fastdispatch
        -c++
    )

    if (NOT UWP)
        # UWP does not support UnmanagedType.CustomMarshaler
        list(APPEND GENERATOR_OPTIONS -DSWIG_CSHARP_NO_STRING_HELPER=1)
    endif ()

    if (URHO3D_SWIG_DEBUG_TMSEARCH)
        list(APPEND GENERATOR_OPTIONS -debug-tmsearch)
    endif ()

    # Native library name matches target name by default
    if (BIND_EMBED)
        list (APPEND GENERATOR_OPTIONS -dllimport $<TARGET_NAME:${BIND_EMBED}>)
    else ()
        if (IOS OR WEB)
            list (APPEND GENERATOR_OPTIONS -dllimport __Internal)
        else ()
            list (APPEND GENERATOR_OPTIONS -dllimport $<TARGET_NAME:${BIND_TARGET}>)
        endif ()
    endif ()

    # Platform defines with "__" prefix and suffix
    foreach(def IOS WEB ANDROID APPLE)
        if (${${def}})
            list (APPEND GENERATOR_OPTIONS -D__${def}__=1)
        endif ()
    endforeach()

    # Other platform defines
    foreach(def WIN32 MSVC LINUX UNIX MACOS UWP)
        if (${${def}})
            list (APPEND GENERATOR_OPTIONS -D${def}=1)
        endif ()
    endforeach()

    # The bindings import Urho3D.i and include Urho3DNet/Native/SWIGHelpers.h. Linking Urho3DCSharp gives the target
    # the include directories for both. The embedded Urho3DCSharp target itself does not need this.
    if (NOT BIND_EMBED AND TARGET Urho3DCSharp AND NOT "${BIND_TARGET}" STREQUAL "Urho3DCSharp")
        target_link_libraries(${BIND_TARGET} PUBLIC Urho3DCSharp)
    endif ()

    # Parse bindings using same compile definitions as built target
    __TARGET_GET_PROPERTIES_RECURSIVE(INCLUDES ${BIND_TARGET} INTERFACE_INCLUDE_DIRECTORIES)
    __TARGET_GET_PROPERTIES_RECURSIVE(DEFINES  ${BIND_TARGET} INTERFACE_COMPILE_DEFINITIONS)
    if (TARGET "${BIND_EMBED}")
        __TARGET_GET_PROPERTIES_RECURSIVE(INCLUDES ${BIND_EMBED} INTERFACE_INCLUDE_DIRECTORIES)
        __TARGET_GET_PROPERTIES_RECURSIVE(DEFINES  ${BIND_EMBED} INTERFACE_COMPILE_DEFINITIONS)
    endif ()

    if (BIND_DEPENDS)
        foreach(dep ${BIND_DEPENDS})
            __TARGET_GET_PROPERTIES_RECURSIVE(INCLUDES ${dep} INTERFACE_INCLUDE_DIRECTORIES)
            __TARGET_GET_PROPERTIES_RECURSIVE(DEFINES  ${dep} INTERFACE_COMPILE_DEFINITIONS)
        endforeach()
    endif ()

    if (INCLUDES)
        list (REMOVE_DUPLICATES INCLUDES)
    endif ()
    if (DEFINES)
        list (REMOVE_DUPLICATES DEFINES)
    endif ()
    foreach(item ${INCLUDES})
        list(APPEND GENERATOR_OPTIONS -I${item})
    endforeach()

    # Should not be relevant for bindings, breaks on Xcode. See URHO3D_CSHARP_BIND_CONFIG for more info.
    if (CMAKE_GENERATOR STREQUAL "Xcode")
        list(FILTER GENERATOR_OPTIONS EXCLUDE REGEX "SDL/include-config-.+$")
    endif ()

    # Defines must have a value, otherwise SWIG gets confused
    foreach(item ${DEFINES})
        string(FIND "${item}" "=" EQUALITY_INDEX)
        if (EQUALITY_INDEX EQUAL -1)
            set (item "${item}=1")
        endif ()
        list(APPEND GENERATOR_OPTIONS "-D${item}")
    endforeach()

    # Main .i file
    list(APPEND GENERATOR_OPTIONS ${BIND_SWIG})

    # Finalize option list
    string(REGEX REPLACE "[^;]+\\$<COMPILE_LANGUAGE:[^;]+;" "" GENERATOR_OPTIONS "${GENERATOR_OPTIONS}")    # COMPILE_LANGUAGE creates ambiguity, remove.
    list(REMOVE_DUPLICATES GENERATOR_OPTIONS)
    string(REPLACE ";" "\n" GENERATOR_OPTIONS "${GENERATOR_OPTIONS}")
    file(GENERATE OUTPUT "GeneratorOptions_${BIND_TARGET}_${URHO3D_CSHARP_BIND_CONFIG}.txt" CONTENT "${GENERATOR_OPTIONS}" CONDITION $<COMPILE_LANGUAGE:CXX>)

    # Swig generator command
    setup_external_tool(swig SWIG_EXECUTABLE)
    add_custom_command(OUTPUT ${BIND_OUT_FILE}
        COMMAND ${CMAKE_COMMAND} -E remove_directory ${BIND_OUT_DIR}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${BIND_OUT_DIR}
        COMMAND "${CMAKE_COMMAND}" -E env "SWIG_LIB=${URHO3D_SWIG_LIB_DIR}" ${SWIG_EXECUTABLE}
        ARGS -outdir "${BIND_OUT_DIR}"
             -o "${BIND_OUT_FILE}"
             @"${CMAKE_CURRENT_BINARY_DIR}/GeneratorOptions_${BIND_TARGET}_${URHO3D_CSHARP_BIND_CONFIG}.txt" > ${CMAKE_CURRENT_BINARY_DIR}/swig_${BIND_TARGET}.log

        MAIN_DEPENDENCY ${BIND_SWIG}
        DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/GeneratorOptions_${BIND_TARGET}_${URHO3D_CSHARP_BIND_CONFIG}.txt" ${BIND_DEPENDS} $<TARGET_NAME_IF_EXISTS:swig>
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT "SWIG: Generating C# bindings for ${BIND_TARGET}")

    if (BIND_EMBED)
        # Bindings are part of another target
        target_sources(${BIND_EMBED} PRIVATE ${BIND_OUT_FILE})
    else ()
        # Bindings are part of target bindings are generated for
        target_sources(${BIND_TARGET} PRIVATE ${BIND_OUT_FILE})
    endif ()

    if (BIND_CSPROJ)
        get_filename_component(BIND_MANAGED_TARGET "${BIND_CSPROJ}" NAME_WLE)
        add_target_csharp(
            TARGET ${BIND_MANAGED_TARGET}
            PROJECT ${BIND_CSPROJ}
            OUTPUT ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${BIND_MANAGED_TARGET})
        if (TARGET ${BIND_MANAGED_TARGET})
            # Real C# target. Imported targets cannot have dependencies.
            set (BIND_DEPENDENCIES "")
            foreach (dep ${BIND_TARGET} ${BIND_EMBED})
                if (TARGET ${dep})
                    get_target_property(dep_imported ${dep} IMPORTED)
                    if (NOT dep_imported)
                        list (APPEND BIND_DEPENDENCIES ${dep})
                    endif ()
                endif ()
            endforeach ()
            if (BIND_DEPENDENCIES)
                add_dependencies(${BIND_MANAGED_TARGET} ${BIND_DEPENDENCIES})
            endif ()
        endif ()
    endif ()
endfunction ()
