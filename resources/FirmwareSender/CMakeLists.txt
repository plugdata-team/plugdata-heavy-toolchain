cmake_minimum_required(VERSION 3.20)
project(FirmwareSender LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_executable(FirmwareSender
    "${FIRMWARE_SOURCE}/Source/FirmwareSender.cpp"
    "${FIRMWARE_SOURCE}/Source/crc32.c"
    "${FIRMWARE_SOURCE}/Source/sysex.c")
if(APPLE)
    enable_language(OBJCXX)
    set(module_extension mm)
else()
    set(module_extension cpp)
endif()
foreach(module juce_core juce_events juce_audio_basics juce_audio_devices)
    target_sources(FirmwareSender PRIVATE "${JUCE_SOURCE}/modules/${module}/${module}.${module_extension}")
endforeach()
target_include_directories(FirmwareSender PRIVATE "${JUCE_SOURCE}/modules" "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_definitions(FirmwareSender PRIVATE
    JUCE_GLOBAL_MODULE_SETTINGS_INCLUDED=1 JUCE_STANDALONE_APPLICATION=1
    JUCE_USE_CURL=0 JUCE_WEB_BROWSER=0 JUCE_JACK=0 JUCE_ASIO=0
    JUCE_MODAL_LOOPS_PERMITTED=1 NDEBUG=1)
if(APPLE)
    target_link_libraries(FirmwareSender PRIVATE "-framework Cocoa" "-framework CoreAudio"
        "-framework CoreMIDI" "-framework AudioToolbox" "-framework IOKit" "-framework Security"
        "-framework Accelerate")
elseif(WIN32)
    target_link_options(FirmwareSender PRIVATE -static)
    target_link_libraries(FirmwareSender PRIVATE winmm wininet ole32 oleaut32 uuid ws2_32 version
        advapi32 shlwapi shell32 comdlg32 imm32 setupapi)
else()
    target_compile_definitions(FirmwareSender PRIVATE JUCE_ALSA=1)
    target_link_options(FirmwareSender PRIVATE -static-libgcc -static-libstdc++)
    target_link_libraries(FirmwareSender PRIVATE asound pthread dl rt)
    set_target_properties(FirmwareSender PROPERTIES INSTALL_RPATH "$ORIGIN/../lib")
endif()
install(TARGETS FirmwareSender RUNTIME DESTINATION bin)
