#vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

# Archive checksums for a moving GitHub branch are not stable.
# Fetch the exact commit using Git instead of downloading a mutable archive.
vcpkg_from_git(
        OUT_SOURCE_PATH SOURCE_PATH
        URL "https://github.com/ryzom/luabind.git"
        REF "af52fcf7cc903437d739ee2c9bee92e6025b4908"
        FETCH_REF "master"
)

vcpkg_cmake_configure(
        SOURCE_PATH "${SOURCE_PATH}"
)

vcpkg_cmake_install()

#vcpkg_cmake_config_fixup(PACKAGE_NAME "Luabind")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")