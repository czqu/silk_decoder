project(Silk)

file(GLOB_RECURSE SILK_SOURCES "src/*.c" "src/*.S")

add_library(silk STATIC ${SILK_SOURCES})

target_include_directories(silk PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/interface>
        $<INSTALL_INTERFACE:include>
)