cmake_minimum_required(VERSION 3.16)
project(silimate_selftest C)

# Link a real shared library so the bundling scripts have something to find and
# rewrite. A binary with no non-system dependencies would test nothing.
find_package(ZLIB REQUIRED)

add_executable(silimate-selftest main.c)
target_link_libraries(silimate-selftest PRIVATE ZLIB::ZLIB)

install(TARGETS silimate-selftest RUNTIME DESTINATION bin)
