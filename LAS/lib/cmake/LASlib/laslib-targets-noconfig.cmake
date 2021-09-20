#----------------------------------------------------------------
# Generated CMake target import file.
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "LASlib" for configuration ""
set_property(TARGET LASlib APPEND PROPERTY IMPORTED_CONFIGURATIONS NOCONFIG)
set_target_properties(LASlib PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_NOCONFIG "CXX"
  IMPORTED_LOCATION_NOCONFIG "${_IMPORT_PREFIX}/lib/LASlib/libLASlib.a"
  )

list(APPEND _IMPORT_CHECK_TARGETS LASlib )
list(APPEND _IMPORT_CHECK_FILES_FOR_LASlib "${_IMPORT_PREFIX}/lib/LASlib/libLASlib.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
