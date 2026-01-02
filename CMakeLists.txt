cmake_minimum_required(VERSION 3.12)
project(Skalp_external_application)

# --- Configuration ---
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Define source files
set(SOURCES
    ce_src_app/main.cpp
    ce_src_app/sketchup.cpp
    ce_src_app/setup_hiddenline_style.cpp
    ce_src_app/setup_reversed_scene.cpp
    ce_src_app/get_exploded_entities.cpp
    ce_src_app/model_style.cpp
    ce_src_app/skalp_convert.cpp
    ce_src_app/create_layer_materials.cpp
    ce_src_app/skalp_layout_connection.cpp
    ce_src_app/base64/base64.cpp
)

# --- SketchUp SDK Setup ---
set(SKETCHUP_SDK_PATH "${CMAKE_CURRENT_SOURCE_DIR}/ce_src_app/frameworks" CACHE PATH "Path to SketchUp SDK")

if(APPLE)
    # macOS Configuration
    find_library(SKETCHUP_API SketchUpAPI PATHS "${SKETCHUP_SDK_PATH}" SUFFIXES SketchUpAPI.framework NO_DEFAULT_PATH)
    find_library(LAYOUT_API LayOutAPI PATHS "${SKETCHUP_SDK_PATH}" SUFFIXES LayOutAPI.framework NO_DEFAULT_PATH)

    add_executable(${PROJECT_NAME} ${SOURCES})
    set_target_properties(${PROJECT_NAME} PROPERTIES 
        OUTPUT_NAME "Skalp"
        INSTALL_RPATH "@executable_path/"
        BUILD_WITH_INSTALL_RPATH TRUE
    )

    # Check if we found it (basic check, CI might mock this)
    if(SKETCHUP_API)
        target_link_libraries(${PROJECT_NAME} PRIVATE "${SKETCHUP_API}")
    endif()
    if(LAYOUT_API)
        target_link_libraries(${PROJECT_NAME} PRIVATE "${LAYOUT_API}")
    endif()
    
    include_directories("${SKETCHUP_SDK_PATH}/SketchUpAPI.framework/Headers")
    include_directories("${SKETCHUP_SDK_PATH}/LayOutAPI.framework/Headers")
    
elseif(WIN32)
    # Windows Configuration
    include_directories("${SKETCHUP_SDK_PATH}/headers")
    link_directories("${SKETCHUP_SDK_PATH}/binaries/x64") 

    add_library(${PROJECT_NAME} SHARED ${SOURCES})
    # target_link_libraries(${PROJECT_NAME} PRIVATE "SketchUpAPI") 
endif()

# --- SkalpC Target (The "Missing" Extension) ---
# Includes embedded Clipper, base64, etc.

set(SKALPC_SOURCES
    ce_src_skalpc/src/SkalpC.cpp
    ce_src_skalpc/src/clipper/clipper.cpp
    ce_src_skalpc/src/base64/base64.cpp
    ce_src_skalpc/src/GeneralHash/GeneralHashFunctions.cpp
    ce_src_skalpc/src/GeneralHash/HashTest.cpp
    ce_src_skalpc/src/RubyUtils/RubyUtils.cpp
)

if(APPLE)
    add_library(SkalpC MODULE ${SKALPC_SOURCES})
    # target_link_libraries(SkalpC PRIVATE "${SKETCHUP_API}") # Reuse API var from above
    if(SKETCHUP_API)
        target_link_libraries(SkalpC PRIVATE "${SKETCHUP_API}")
    endif()
    # MODULE creates a flat .bundle file (Ruby extension), not a macOS app bundle directory
    # BUNDLE TRUE creates directory structure (Contents/MacOS/...) which Ruby can't load
    set_target_properties(SkalpC PROPERTIES 
        MACOSX_BUNDLE FALSE
        PREFIX ""
        SUFFIX ".bundle"
    )
    
    # Find Ruby headers (using the current ruby environment)
    execute_process(COMMAND ruby -e "require 'rbconfig'; print RbConfig::CONFIG['rubyhdrdir']" OUTPUT_VARIABLE RUBY_HDR_DIR)
    execute_process(COMMAND ruby -e "require 'rbconfig'; print RbConfig::CONFIG['rubyarchhdrdir']" OUTPUT_VARIABLE RUBY_ARCH_HDR_DIR)

    target_include_directories(SkalpC PRIVATE 
        ce_src_skalpc/src 
        ce_src_skalpc/src/clipper
        ce_src_skalpc/src/base64
        ce_src_skalpc/src/GeneralHash
        ce_src_skalpc/src/RubyUtils
        ${RUBY_HDR_DIR}
        ${RUBY_ARCH_HDR_DIR}
    )

    if(APPLE)
        set_target_properties(SkalpC PROPERTIES LINK_FLAGS "-undefined dynamic_lookup")
    endif()

elseif(WIN32)
    add_library(SkalpC SHARED ${SKALPC_SOURCES})
    target_include_directories(SkalpC PRIVATE 
        ce_src_skalpc/src 
        ce_src_skalpc/src/clipper
        ce_src_skalpc/src/base64
        ce_src_skalpc/src/GeneralHash
        ce_src_skalpc/src/RubyUtils
    )
endif()


