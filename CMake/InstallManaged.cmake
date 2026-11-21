# Copyright (c) 2017-2026 the rbfx project.
# This work is licensed under the terms of the MIT license.
# For a copy, see <https:#opensource.org/licenses/MIT> or the accompanying LICENSE file.

cmake_policy(PUSH)
cmake_policy(SET CMP0009 NEW)

# CMake is not aware of files C# builds produce. Since those files end up in
# binary directory we inconditionally install any possible C# artifacts.
file (GLOB_RECURSE INSTALL_FILES
    RELATIVE ${MANAGED_BINARY_DIR}
    ${MANAGED_BINARY_DIR}/bin/*.dll
    ${MANAGED_BINARY_DIR}/bin/*.exe
    ${MANAGED_BINARY_DIR}/bin/*.exe.config
    ${MANAGED_BINARY_DIR}/bin/*.deps.json
    ${MANAGED_BINARY_DIR}/bin/*.runtimeconfig.json
    ${MANAGED_BINARY_DIR}/bin/*.pdb
)

# Test frameworks are not part of the SDK.
list (FILTER INSTALL_FILES EXCLUDE REGEX "/(xunit|testhost|Microsoft\\.TestPlatform|Microsoft\\.VisualStudio|Microsoft\\.Testing)[^/]*$")

foreach (file ${INSTALL_FILES})
    set (SOURCE_FILE ${MANAGED_BINARY_DIR}/${file})
    set (DEST_FILE ${CMAKE_INSTALL_PREFIX}/${file})
    if (NOT EXISTS "${DEST_FILE}")
        get_filename_component(DEST_DIR "${DEST_FILE}" DIRECTORY)
        file (MAKE_DIRECTORY "${DEST_DIR}")
        file (COPY ${SOURCE_FILE} DESTINATION "${DEST_DIR}")
    endif ()
endforeach()

cmake_policy(POP)
