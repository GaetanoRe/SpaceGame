# ---------------------------------------------------------------------------
# Graphics backend autodetection
#
#   Android, iOS                                 -> OpenGL ES 3.0
#   Web (Emscripten)                             -> OpenGL ES 2.0  (WebGL 1)
#   Raspberry Pi 4 / 5 / 400 / 500 / CM4 / CM5   -> OpenGL ES 3.0  (V3D)
#   Raspberry Pi Zero / Zero 2 / 1 / 2 / 3 / CM3 -> OpenGL ES 2.0  (VideoCore IV)
#   Other ARM boards (Rockchip, Amlogic, Allwinner, Snapdragon, ...)
#                                                -> from the kernel DRM driver
#   PC-class GPUs, macOS, Windows                -> OpenGL 3.3 core
#
# Why ARM boards get GLES rather than desktop GL: Mesa's ARM drivers implement
# GLES well ahead of desktop GL. Panfrost (Mali Bifrost/Valhall, so most
# Rockchip and Amlogic boards) advertises GLES 3.1 but only desktop GL 3.1, so
# asking for a 3.3 core context can fail on a GPU that is otherwise plenty
# capable. Checking the driver is also why we do not try to recognise SoC names:
# "Rockchip RK3588" tells you nothing on its own, "panfrost" tells you GLES 3.1.
# ---------------------------------------------------------------------------

# Drivers whose Mesa implementation does GLES 3.x.
set(SPACEGAME_DRM_GLES3_DRIVERS
    v3d         # Raspberry Pi 4 / 5
    panfrost    # Mali Midgard/Bifrost/Valhall: RK3399, RK3588, Amlogic, ...
    panthor     # Mali CSF (G310/G610/G710) on newer kernels
    msm         # Adreno / Snapdragon (freedreno)
    powervr     # Imagination, upstream driver
    tegra       # Jetson with the open stack
)

# Drivers that stop at GLES 2.0.
set(SPACEGAME_DRM_GLES2_DRIVERS
    vc4         # VideoCore IV: Pi Zero / Zero 2 W / 1 / 2 / 3
    lima        # Mali-400 / 450 (Utgard): older Allwinner, early Amlogic
    etnaviv     # Vivante: GLES 3 only on the newest cores, so assume 2.0
)

# PC-class drivers: full desktop OpenGL.
set(SPACEGAME_DRM_DESKTOP_DRIVERS
    i915 xe amdgpu radeon nouveau nvidia nvidia-drm asahi
    virtio_gpu vmwgfx simpledrm vkms
)

# Reads the board name the firmware exposes. Empty on anything that is not a
# device-tree machine (i.e. every normal PC), which is exactly what we want.
function(spacegame_read_board_model out_var)
    set(model "")
    foreach(candidate
        "${CMAKE_SYSROOT}/sys/firmware/devicetree/base/model"
        "${CMAKE_SYSROOT}/proc/device-tree/model")
        if(EXISTS "${candidate}")
            file(READ "${candidate}" model)
            break()
        endif()
    endforeach()

    # Fallback for kernels without a mounted device tree: /proc/cpuinfo carries
    # a "Model" line on Raspberry Pi OS.
    if(model STREQUAL "" AND CMAKE_SYSROOT STREQUAL "" AND EXISTS "/proc/cpuinfo")
        file(STRINGS "/proc/cpuinfo" cpuinfo_model REGEX "^Model[ \t]*:")
        if(cpuinfo_model)
            list(GET cpuinfo_model 0 model)
        endif()
    endif()

    # The device-tree string is NUL terminated; strip that and anything else
    # that is not printable ASCII so the regexes stay predictable.
    string(REGEX REPLACE "[^ -~]" "" model "${model}")
    string(STRIP "${model}" model)
    set(${out_var} "${model}" PARENT_SCOPE)
endfunction()

# Name of the kernel driver behind the first render node. Render nodes are the
# GPUs that actually draw, so this skips display-only devices -- on a Pi 4 card0
# is vc4 (display) while the renderer is v3d, and picking the card would
# downgrade the board to GLES 2.0.
function(spacegame_read_drm_driver out_var)
    set(driver "")
    file(GLOB render_nodes "${CMAKE_SYSROOT}/sys/class/drm/renderD*")
    foreach(node IN LISTS render_nodes)
        if(EXISTS "${node}/device/uevent")
            file(STRINGS "${node}/device/uevent" driver_lines REGEX "^DRIVER=")
            if(driver_lines)
                list(GET driver_lines 0 driver_line)
                string(REGEX REPLACE "^DRIVER=" "" driver "${driver_line}")
                break()
            endif()
        endif()
    endforeach()
    set(${out_var} "${driver}" PARENT_SCOPE)
endfunction()

# Sets out_backend to GL33, GLES3 or GLES2, and out_reason to a short
# explanation of how we got there (for the configure-time message).
function(spacegame_detect_graphics out_backend out_reason)
    if(ANDROID)
        # Every Android device raylib can target does GLES 3.0 (API level 18+).
        set(${out_backend} "GLES3" PARENT_SCOPE)
        set(${out_reason} "Android" PARENT_SCOPE)
        return()
    elseif(IOS OR CMAKE_SYSTEM_NAME STREQUAL "iOS")
        # GLES 3.0 covers every iOS device since the A7. Apple deprecated GLES
        # in iOS 12 but it still runs; Metal is the long-term answer.
        set(${out_backend} "GLES3" PARENT_SCOPE)
        set(${out_reason} "iOS" PARENT_SCOPE)
        return()
    elseif(EMSCRIPTEN)
        # ES 2.0 is WebGL 1 and runs anywhere; ES 3.0 is WebGL 2, which every
        # current browser has, and which raylib builds with MIN_WEBGL_VERSION=2.
        set(${out_backend} "GLES2" PARENT_SCOPE)
        set(${out_reason} "Emscripten (WebGL 1; -DSPACEGAME_GFX=GLES3 for WebGL 2)" PARENT_SCOPE)
        return()
    elseif(APPLE)
        set(${out_backend} "GL33" PARENT_SCOPE)
        set(${out_reason} "macOS (4.1 is the ceiling, raylib forces 3.3 here anyway)" PARENT_SCOPE)
        return()
    elseif(WIN32)
        set(${out_backend} "GL33" PARENT_SCOPE)
        set(${out_reason} "Windows desktop" PARENT_SCOPE)
        return()
    endif()

    # Host files describe the build machine, so they are only worth reading when
    # that is also the machine that will run the game (or when a sysroot points
    # us at the target's copy of them).
    set(can_probe TRUE)
    if(CMAKE_CROSSCOMPILING AND CMAKE_SYSROOT STREQUAL "")
        set(can_probe FALSE)
    endif()

    if(can_probe)
        spacegame_read_board_model(board)
        if(board MATCHES "Raspberry Pi (Compute Module )?[4-9]")
            # Pi 4, 400, 5, 500, CM4, CM5: V3D, GLES 3.1 capable.
            set(${out_backend} "GLES3" PARENT_SCOPE)
            set(${out_reason} "board '${board}'" PARENT_SCOPE)
            return()
        elseif(board MATCHES "Raspberry Pi")
            # Pi Zero / Zero 2 W / 1 / 2 / 3 / CM1 / CM3: VideoCore IV, GLES 2.0 only.
            set(${out_backend} "GLES2" PARENT_SCOPE)
            set(${out_reason} "board '${board}'" PARENT_SCOPE)
            return()
        endif()

        spacegame_read_drm_driver(drm_driver)
        if(drm_driver)
            if(drm_driver IN_LIST SPACEGAME_DRM_GLES3_DRIVERS)
                set(${out_backend} "GLES3" PARENT_SCOPE)
                set(${out_reason} "DRM driver '${drm_driver}'" PARENT_SCOPE)
                return()
            elseif(drm_driver IN_LIST SPACEGAME_DRM_GLES2_DRIVERS)
                set(${out_backend} "GLES2" PARENT_SCOPE)
                set(${out_reason} "DRM driver '${drm_driver}'" PARENT_SCOPE)
                return()
            elseif(drm_driver IN_LIST SPACEGAME_DRM_DESKTOP_DRIVERS)
                set(${out_backend} "GL33" PARENT_SCOPE)
                set(${out_reason} "DRM driver '${drm_driver}'" PARENT_SCOPE)
                return()
            endif()
        endif()
    endif()

    # Last resort: guess from the CPU architecture. An unrecognised ARM machine
    # is far more likely to be a GLES-first SBC or handheld than a workstation
    # with a PC-class GPU (those are caught by the driver table above).
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64|armv8)")
        set(${out_backend} "GLES3" PARENT_SCOPE)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm|armv7)")
        # 32-bit ARM is mostly Mali-400 era hardware.
        set(${out_backend} "GLES2" PARENT_SCOPE)
    else()
        set(${out_backend} "GL33" PARENT_SCOPE)
    endif()

    if(can_probe)
        set(reason "unrecognised hardware, guessed from CPU '${CMAKE_SYSTEM_PROCESSOR}'")
    else()
        set(reason "cross-compiling without a sysroot, guessed from CPU '${CMAKE_SYSTEM_PROCESSOR}'")
    endif()
    set(${out_reason} "${reason} -- set -DSPACEGAME_GFX if this is wrong" PARENT_SCOPE)
endfunction()
