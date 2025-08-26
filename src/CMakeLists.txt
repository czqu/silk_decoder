# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.15)
set(CMAKE_OSX_DEPLOYMENT_TARGET 10.11)
project(silk_decoder_library VERSION 0.0.1 LANGUAGES C)

add_subdirectory(silk)
if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    set(CMAKE_OSX_ARCHITECTURES "x86_64;arm64")
endif ()

if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin" OR ${CMAKE_SYSTEM_NAME} MATCHES "iOS")
    add_library(silk_decoder STATIC
            "silk_decoder.c" )
else ()
    add_library(silk_decoder SHARED
            "silk_decoder.c" )
endif ()
target_link_libraries(silk_decoder PRIVATE silk)
set_target_properties(silk_decoder PROPERTIES
        PUBLIC_HEADER silk_decoder.h
        OUTPUT_NAME "silk_decoder"
)

target_compile_definitions(silk_decoder PUBLIC DART_SHARED_LIB)

if (ANDROID)
    # Support Android 15 16k page size
    target_link_options(silk_decoder PRIVATE "-Wl,-z,max-page-size=16384")
endif ()
