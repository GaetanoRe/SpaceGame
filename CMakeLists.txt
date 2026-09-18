cmake_minimum_required(VERSION 3.16)
project(SpaceGame C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

include(FetchContent)

set(FETCHCONTENT_QUIET FALSE)
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(BUILD_GAMES OFF CACHE BOOL "" FORCE)
set(OPENGL_VERSION "2.1" CACHE STRING "" FORCE)

# Build raylib's bundled GLFW with both display backends on Linux. GLFW 3.4
# selects the platform at runtime (GLFW_ANY_PLATFORM): Wayland when
# WAYLAND_DISPLAY is set, X11 otherwise. raylib defaults Wayland to OFF, so we
# turn it on explicitly, but only when the Wayland development packages are
# available -- otherwise we stay X11-only and the build still works.
if(UNIX AND NOT APPLE)
    find_package(PkgConfig QUIET)
    set(SPACEGAME_WAYLAND OFF)
    if(PkgConfig_FOUND)
        pkg_check_modules(SPACEGAME_WAYLAND_DEPS
            wayland-client wayland-cursor wayland-egl xkbcommon)
        find_program(WAYLAND_SCANNER_EXECUTABLE NAMES wayland-scanner)
        if(SPACEGAME_WAYLAND_DEPS_FOUND AND WAYLAND_SCANNER_EXECUTABLE)
            set(SPACEGAME_WAYLAND ON)
        endif()
    endif()

    if(SPACEGAME_WAYLAND)
        message(STATUS "SpaceGame: building GLFW with Wayland + X11 (Wayland preferred at runtime)")
    else()
        message(STATUS "SpaceGame: Wayland dev packages not found, building GLFW with X11 only")
    endif()

    set(GLFW_BUILD_WAYLAND ${SPACEGAME_WAYLAND} CACHE BOOL "" FORCE)
    set(GLFW_BUILD_X11 ON CACHE BOOL "" FORCE)
endif()

FetchContent_Declare(
    raylib
    GIT_REPOSITORY https://github.com/raysan5/raylib.git
    GIT_TAG 5.5
    GIT_SHALLOW TRUE
    UPDATE_DISCONNECTED TRUE
)
FetchContent_MakeAvailable(raylib)

FetchContent_Declare(
    sqlite3
    URL https://www.sqlite.org/2026/sqlite-amalgamation-3530400.zip
    URL_HASH SHA3_256=628a44cfe82c66aed1ccbbe85a562d2e33ebe64b3288981ed76285612227934e
)
FetchContent_MakeAvailable(sqlite3)

add_library(sqlite3 STATIC "${sqlite3_SOURCE_DIR}/sqlite3.c")
target_include_directories(sqlite3 PUBLIC "${sqlite3_SOURCE_DIR}")
if(UNIX)
    target_link_libraries(sqlite3 PUBLIC pthread ${CMAKE_DL_LIBS})
endif()

file(GLOB_RECURSE GAME_SOURCES CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/src/*.c")

add_executable(${PROJECT_NAME} ${GAME_SOURCES})

target_include_directories(${PROJECT_NAME} PRIVATE "${CMAKE_SOURCE_DIR}/include")
target_link_libraries(${PROJECT_NAME} PRIVATE raylib sqlite3)

if(APPLE)
    target_link_libraries(${PROJECT_NAME} PRIVATE "-framework IOKit" "-framework Cocoa" "-framework OpenGL")
endif()
