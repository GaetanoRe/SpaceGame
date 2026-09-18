cmake_minimum_required(VERSION 3.16)
project(SpaceGame C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

include(FetchContent)

set(FETCHCONTENT_QUIET FALSE)
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(BUILD_GAMES OFF CACHE BOOL "" FORCE)
# ---------------------------------------------------------------------------
# Graphics backend selection
#
# The board/driver detection lives in cmake/DetectGraphics.cmake, which also
# documents the full platform -> backend table. Override the autodetection with
# -DSPACEGAME_GFX=GL33|GLES3|GLES2 (needed when cross-compiling, where the build
# host is not the machine that runs the game).
# ---------------------------------------------------------------------------
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
include(DetectGraphics)

set(SPACEGAME_GFX "AUTO" CACHE STRING "Graphics backend: AUTO, GL33, GLES3 or GLES2")
set_property(CACHE SPACEGAME_GFX PROPERTY STRINGS AUTO GL33 GLES3 GLES2)

if(SPACEGAME_GFX STREQUAL "AUTO")
    spacegame_detect_graphics(SPACEGAME_GFX_RESOLVED SPACEGAME_GFX_REASON)
else()
    set(SPACEGAME_GFX_RESOLVED "${SPACEGAME_GFX}")
    set(SPACEGAME_GFX_REASON "SPACEGAME_GFX=${SPACEGAME_GFX}")
endif()

if(SPACEGAME_GFX_RESOLVED STREQUAL "GL33")
    set(SPACEGAME_RAYLIB_GL "3.3")
elseif(SPACEGAME_GFX_RESOLVED STREQUAL "GLES3")
    set(SPACEGAME_RAYLIB_GL "ES 3.0")
elseif(SPACEGAME_GFX_RESOLVED STREQUAL "GLES2")
    set(SPACEGAME_RAYLIB_GL "ES 2.0")
else()
    message(FATAL_ERROR "SpaceGame: unknown SPACEGAME_GFX '${SPACEGAME_GFX}' (use AUTO, GL33, GLES3 or GLES2)")
endif()

message(STATUS "SpaceGame: graphics backend ${SPACEGAME_GFX_RESOLVED} (raylib OPENGL_VERSION \"${SPACEGAME_RAYLIB_GL}\") -- ${SPACEGAME_GFX_REASON}")
set(OPENGL_VERSION "${SPACEGAME_RAYLIB_GL}" CACHE STRING "" FORCE)

# Nothing below is wired up for the non-desktop targets yet: Android needs
# -DPLATFORM=Android plus an NDK toolchain, web needs -DPLATFORM=Web, and raylib
# 5.5 has no iOS backend in its CMake at all (SDL2 via -DPLATFORM=SDL is the
# usual route). The GL version is settled above so only that work is left when
# we get there. Android's libGLESv2.so already exports the ES 3.0 entry points,
# so no extra link is needed there either.
if(ANDROID OR IOS OR CMAKE_SYSTEM_NAME STREQUAL "iOS" OR EMSCRIPTEN)
    message(WARNING "SpaceGame: ${CMAKE_SYSTEM_NAME} graphics are configured, but the platform/packaging path is not set up yet")
endif()

# raylib's desktop backend creates GLES contexts through EGL, and with ES 3.0 it
# calls into libGLESv2 directly (ES 2.0 loads its entry points through GLFW), so
# make sure the client libraries are actually installed before we get a wall of
# link errors. Mobile SDKs ship their own, so this is a Linux/BSD check only.
if(SPACEGAME_GFX_RESOLVED MATCHES "^GLES" AND UNIX AND NOT APPLE AND NOT ANDROID AND NOT EMSCRIPTEN)
    find_library(SPACEGAME_EGL_LIBRARY NAMES EGL)
    if(NOT SPACEGAME_EGL_LIBRARY)
        message(FATAL_ERROR
            "SpaceGame: libEGL not found, required for OpenGL ES. "
            "On Raspberry Pi OS / Debian: sudo apt install libegl1-mesa-dev libgles2-mesa-dev")
    endif()
    if(SPACEGAME_GFX_RESOLVED STREQUAL "GLES3")
        find_library(SPACEGAME_GLESV2_LIBRARY NAMES GLESv2)
        find_path(SPACEGAME_GLES3_INCLUDE_DIR NAMES GLES3/gl3.h)
        if(NOT SPACEGAME_GLESV2_LIBRARY OR NOT SPACEGAME_GLES3_INCLUDE_DIR)
            message(FATAL_ERROR
                "SpaceGame: OpenGL ES 3.0 headers/libraries not found. "
                "On Raspberry Pi OS / Debian: sudo apt install libgles2-mesa-dev libegl1-mesa-dev")
        endif()

        # raylib 5.5's ES 3.0 path calls glDrawBuffersEXT() (an EXT_draw_buffers
        # entry point) instead of the ES 3.0 core glDrawBuffers(). Mesa exports
        # the extension only through eglGetProcAddress, so the link fails. Both
        # have the same signature, so rename the call at compile time when the
        # EXT symbol really is missing.
        include(CheckLibraryExists)
        check_library_exists("${SPACEGAME_GLESV2_LIBRARY}" glDrawBuffersEXT "" SPACEGAME_HAVE_DRAW_BUFFERS_EXT)
    endif()
endif()

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

# raylib links its own dependencies with the plain target_link_libraries()
# signature, so we have to stay plain here too. The ES 3.0 path in rlgl calls
# libGLESv2 directly instead of loading it through GLFW, hence the extra link.
if(SPACEGAME_GFX_RESOLVED STREQUAL "GLES3" AND UNIX AND NOT APPLE AND NOT ANDROID AND NOT EMSCRIPTEN)
    target_link_libraries(raylib "${SPACEGAME_GLESV2_LIBRARY}" "${SPACEGAME_EGL_LIBRARY}")
    target_include_directories(raylib PRIVATE "${SPACEGAME_GLES3_INCLUDE_DIR}")
    if(NOT SPACEGAME_HAVE_DRAW_BUFFERS_EXT)
        target_compile_definitions(raylib PUBLIC glDrawBuffersEXT=glDrawBuffers)
    endif()
endif()

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
