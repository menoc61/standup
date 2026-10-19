cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

# The X11 idle reader is compiled in only when the XScreenSaver headers are
# present, so presence stays a bonus rather than a build requirement. X11 is
# required alongside Xss for the same compile: the reader frees its result with
# XFree and asks for the root window, both of which libX11 owns.
if(XSCRNSAVER_FOUND AND X11_FOUND)
  target_compile_definitions(${BINARY_NAME} PRIVATE STANDUP_HAVE_XSCRNSAVER)
  target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::XSCRNSAVER)
  target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::X11)
endif()

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
