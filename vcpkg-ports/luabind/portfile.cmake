#vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
        OUT_SOURCE_PATH SOURCE_PATH
        REPO ryzom/luabind
        REF "af52fcf7cc903437d739ee2c9bee92e6025b4908"
        SHA512 9fe406447e13628e0ad0d03955bb71676fca1a0d5c3ed26dc27154f08cf335b724f39c88cb180b5a37493c8ae005af125c768d7004992c6efabac7c766b6b7ac
        HEAD_REF master
)

vcpkg_cmake_configure(
        SOURCE_PATH "${SOURCE_PATH}"
)

vcpkg_cmake_install()

#vcpkg_cmake_config_fixup(PACKAGE_NAME "Luabind")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")