#!/usr/bin/env python3
"""Regression tests for FindMySQL dependency lists; no database or SDK needed.

Run: python3 CMakeModules/tests/test_find_mysql.py
These configure tests model platform decisions, not Windows compilation/linking.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

PKG_CONFIG = r'''
macro(pkg_check_modules prefix)
  set(${prefix}_FOUND FALSE)
  if((TEST_ROUTE STREQUAL "pkg_mysql" AND "${prefix}" STREQUAL "PC_MYSQL") OR
     (TEST_ROUTE STREQUAL "pkg_mariadb" AND "${prefix}" STREQUAL "PC_MARIADB"))
    set(${prefix}_FOUND TRUE)
    set(${prefix}_INCLUDE_DIRS "${CMAKE_CURRENT_BINARY_DIR}/include")
    set(${prefix}_LINK_LIBRARIES mysql_pkg_fixture)
  endif()
endmacro()
'''
OPENSSL = r'''
set(OPENSSL_FOUND ${TEST_SSL})
set(OPENSSL_LIBRARIES ssl_fixture crypto_fixture)
'''
PROJECT = r'''
cmake_minimum_required(VERSION 3.16)
project(FindMySQLRegression NONE)
set(WIN32 ${TEST_WINDOWS})
set(MSVC ${TEST_WINDOWS})
set(OPENSSL_LIBRARIES ssl_fixture crypto_fixture)
file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/include")
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/mocks")
if(TEST_ROUTE STREQUAL "manual")
  set(MYSQL_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/include")
  set(MYSQL_LIBRARY_RELEASE mysql_release_fixture)
  if(TEST_DEBUG)
    set(MYSQL_LIBRARY_DEBUG mysql_debug_fixture)
  else()
    set(MYSQL_LIBRARY_DEBUG "")
  endif()
elseif(TEST_ROUTE STREQUAL "cached")
  set(MYSQL_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/include")
  set(MYSQL_LIBRARIES optimized mysql_release_fixture debug mysql_debug_fixture)
  if(TEST_WINDOWS)
    list(APPEND MYSQL_LIBRARIES ws2_32 crypt32)
  endif()
elseif(TEST_ROUTE STREQUAL "missing")
  # Defined empty values prevent accidental discovery of host libraries.
  set(MYSQL_INCLUDE_DIR "")
  set(MYSQL_LIBRARY_RELEASE "")
  set(MYSQL_LIBRARY_DEBUG "")
endif()
include("${MODULE_UNDER_TEST}")
if(TEST_ROUTE STREQUAL "missing")
  if(MYSQL_FOUND OR TARGET MySQL::MySQL)
    message(FATAL_ERROR "Missing MySQL must not create an imported target")
  endif()
  return()
endif()
if(NOT MYSQL_FOUND OR NOT TARGET MySQL::MySQL)
  message(FATAL_ERROR "Expected MySQL and its imported target")
endif()
if(NOT "${OPENSSL_LIBRARIES}" STREQUAL "ssl_fixture;crypto_fixture")
  message(FATAL_ERROR "FindMySQL changed OpenSSL's own dependency list")
endif()
get_target_property(target_libs MySQL::MySQL INTERFACE_LINK_LIBRARIES)
foreach(library ws2_32 secur32 crypt32 shlwapi)
  list(FIND MYSQL_LIBRARIES "${library}" legacy_index)
  list(FIND target_libs "${library}" target_index)
  if(TEST_WINDOWS)
    if(legacy_index EQUAL -1 OR target_index EQUAL -1)
      message(FATAL_ERROR "Missing Windows dependency ${library}")
    endif()
    set(occurrences 0)
    foreach(entry IN LISTS MYSQL_LIBRARIES)
      if(entry STREQUAL library)
        math(EXPR occurrences "${occurrences} + 1")
      endif()
    endforeach()
    if(NOT occurrences EQUAL 1)
      message(FATAL_ERROR "Duplicate Windows dependency ${library}")
    endif()
  elseif(NOT legacy_index EQUAL -1 OR NOT target_index EQUAL -1)
    message(FATAL_ERROR "Windows dependency ${library} leaked to another platform")
  endif()
endforeach()
if(TEST_ROUTE STREQUAL "manual" OR TEST_ROUTE STREQUAL "cached")
  if(TEST_DEBUG OR TEST_ROUTE STREQUAL "cached")
    list(SUBLIST MYSQL_LIBRARIES 0 4 selection)
    if(NOT "${selection}" STREQUAL "optimized;mysql_release_fixture;debug;mysql_debug_fixture")
      message(FATAL_ERROR "Release/debug selection was damaged: ${selection}")
    endif()
  endif()
endif()
set(first_libs "${MYSQL_LIBRARIES}")
include("${MODULE_UNDER_TEST}")
if(NOT "${MYSQL_LIBRARIES}" STREQUAL "${first_libs}")
  message(FATAL_ERROR "Repeated include changed the dependency list")
endif()
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--module', type=Path,
                        default=Path(__file__).resolve().parents[1] / 'FindMySQL.cmake')
    args = parser.parse_args()
    if not args.module.is_file():
        parser.error('module does not exist: {}'.format(args.module))
    module = args.module.resolve()
    cmake = shutil.which('cmake')
    if not cmake:
        parser.error('cmake is required')
    cases = []
    for windows in (True, False):
        for route in ('manual', 'cached', 'pkg_mysql', 'pkg_mariadb', 'missing'):
            cases.append((windows, route, False, True))
        cases.append((windows, 'manual', True, True))
        cases.append((windows, 'manual', False, False))
    failures = 0
    with tempfile.TemporaryDirectory(prefix='ryzom-find-mysql-') as work:
        root = Path(work)
        src = root / 'source'
        mocks = src / 'mocks'
        mocks.mkdir(parents=True)
        (src / 'CMakeLists.txt').write_text(PROJECT, encoding='utf-8')
        (mocks / 'FindPkgConfig.cmake').write_text(PKG_CONFIG, encoding='utf-8')
        (mocks / 'FindOpenSSL.cmake').write_text(OPENSSL, encoding='utf-8')
        for windows, route, ssl, debug in cases:
            name = '{}-{}-ssl{}-debug{}'.format(
                'windows' if windows else 'nonwindows', route, int(ssl), int(debug))
            command = [cmake, '-S', str(src), '-B', str(root / name),
                       '-DMODULE_UNDER_TEST=' + module.as_posix(),
                       '-DTEST_WINDOWS=' + ('ON' if windows else 'OFF'),
                       '-DTEST_ROUTE=' + route,
                       '-DTEST_SSL=' + ('ON' if ssl else 'OFF'),
                       '-DTEST_DEBUG=' + ('ON' if debug else 'OFF')]
            try:
                result = subprocess.run(command, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, text=True,
                                        timeout=60, check=False)
            except (OSError, subprocess.TimeoutExpired) as error:
                print('FAIL {}: {}'.format(name, error))
                failures += 1
                continue
            print('{} {}'.format('PASS' if result.returncode == 0 else 'FAIL', name))
            if result.returncode:
                failures += 1
                print(result.stdout)
    print('{}/{} cases passed'.format(len(cases) - failures, len(cases)))
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
