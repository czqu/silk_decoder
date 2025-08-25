# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.15)

project(silk_decoder_library VERSION 0.0.1 LANGUAGES C)
set(CMAKE_C_STANDARD 99)
file(GLOB SILK_SOURCES
        "silk/src/*.c"
        "silk/src/*.S"
)
list(APPEND SILK_SOURCES )

add_library(silk_decoder SHARED
        "silk_decoder.c"
        ${SILK_SOURCES}
)

target_include_directories(silk_decoder PUBLIC
        "${CMAKE_CURRENT_SOURCE_DIR}/silk/interface"
        "${CMAKE_CURRENT_SOURCE_DIR}/silk/src"
)
set_target_properties(silk_decoder PROPERTIES
        PUBLIC_HEADER silk_decoder.h
        OUTPUT_NAME "silk_decoder"
)

target_compile_definitions(silk_decoder PUBLIC DART_SHARED_LIB)

if (ANDROID)
    # Support Android 15 16k page size
    target_link_options(silk_decoder PRIVATE "-Wl,-z,max-page-size=16384")
endif ()
