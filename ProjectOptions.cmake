include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(c__template_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(c__template_setup_options)
  option(c__template_ENABLE_HARDENING "Enable hardening" ON)
  option(c__template_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    c__template_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    c__template_ENABLE_HARDENING
    OFF)

  c__template_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR c__template_PACKAGING_MAINTAINER_MODE)
    option(c__template_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(c__template_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(c__template_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(c__template_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(c__template_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(c__template_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(c__template_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(c__template_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(c__template_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(c__template_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(c__template_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(c__template_ENABLE_PCH "Enable precompiled headers" OFF)
    option(c__template_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(c__template_ENABLE_IPO "Enable IPO/LTO" ON)
    option(c__template_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(c__template_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(c__template_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(c__template_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(c__template_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(c__template_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(c__template_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(c__template_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(c__template_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(c__template_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(c__template_ENABLE_PCH "Enable precompiled headers" OFF)
    option(c__template_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      c__template_ENABLE_IPO
      c__template_WARNINGS_AS_ERRORS
      c__template_ENABLE_USER_LINKER
      c__template_ENABLE_SANITIZER_ADDRESS
      c__template_ENABLE_SANITIZER_LEAK
      c__template_ENABLE_SANITIZER_UNDEFINED
      c__template_ENABLE_SANITIZER_THREAD
      c__template_ENABLE_SANITIZER_MEMORY
      c__template_ENABLE_UNITY_BUILD
      c__template_ENABLE_CLANG_TIDY
      c__template_ENABLE_CPPCHECK
      c__template_ENABLE_COVERAGE
      c__template_ENABLE_PCH
      c__template_ENABLE_CACHE)
  endif()

  c__template_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (c__template_ENABLE_SANITIZER_ADDRESS OR c__template_ENABLE_SANITIZER_THREAD OR c__template_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(c__template_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(c__template_global_options)
  if(c__template_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    c__template_enable_ipo()
  endif()

  c__template_supports_sanitizers()

  if(c__template_ENABLE_HARDENING AND c__template_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR c__template_ENABLE_SANITIZER_UNDEFINED
       OR c__template_ENABLE_SANITIZER_ADDRESS
       OR c__template_ENABLE_SANITIZER_THREAD
       OR c__template_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${c__template_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${c__template_ENABLE_SANITIZER_UNDEFINED}")
    c__template_enable_hardening(c__template_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(c__template_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(c__template_warnings INTERFACE)
  add_library(c__template_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  c__template_set_project_warnings(
    c__template_warnings
    ${c__template_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(c__template_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(c__template_options)
  endif()

  include(cmake/Sanitizers.cmake)
  c__template_enable_sanitizers(
    c__template_options
    ${c__template_ENABLE_SANITIZER_ADDRESS}
    ${c__template_ENABLE_SANITIZER_LEAK}
    ${c__template_ENABLE_SANITIZER_UNDEFINED}
    ${c__template_ENABLE_SANITIZER_THREAD}
    ${c__template_ENABLE_SANITIZER_MEMORY})

  set_target_properties(c__template_options PROPERTIES UNITY_BUILD ${c__template_ENABLE_UNITY_BUILD})

  if(c__template_ENABLE_PCH)
    target_precompile_headers(
      c__template_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(c__template_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    c__template_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(c__template_ENABLE_CLANG_TIDY)
    c__template_enable_clang_tidy(c__template_options ${c__template_WARNINGS_AS_ERRORS})
  endif()

  if(c__template_ENABLE_CPPCHECK)
    c__template_enable_cppcheck(${c__template_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(c__template_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    c__template_enable_coverage(c__template_options)
  endif()

  if(c__template_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(c__template_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(c__template_ENABLE_HARDENING AND NOT c__template_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR c__template_ENABLE_SANITIZER_UNDEFINED
       OR c__template_ENABLE_SANITIZER_ADDRESS
       OR c__template_ENABLE_SANITIZER_THREAD
       OR c__template_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    c__template_enable_hardening(c__template_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
