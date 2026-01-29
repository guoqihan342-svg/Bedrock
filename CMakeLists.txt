cmake_minimum_required(VERSION 3.16)
project(bedrock C)

# -----------------------------
# Options (default: stable & comparable)
# -----------------------------
option(BEDROCK_ENABLE_LTO "Enable Link Time Optimization (local peak, may reduce portability)" OFF)
option(BEDROCK_ENABLE_NATIVE "Enable -march=native (local peak, NOT portable across machines)" OFF)
option(BEDROCK_WERROR "Treat warnings as errors" ON)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Output dirs
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# -----------------------------
# Compiler flags: performance-first, but stable semantics
# -----------------------------
if (MSVC)
  message(FATAL_ERROR "Bedrock v0: Linux-first; MSVC not supported yet.")
endif()

# Base flags
set(BEDROCK_WARN_FLAGS "-Wall;-Wextra;-Wshadow;-Wconversion")
if (BEDROCK_WERROR)
  list(APPEND BEDROCK_WARN_FLAGS "-Werror")
endif()

# Keep floating point semantics stable for correctness gate:
# - avoid aggressive unsafe math by default
# - keep FMA contraction controlled in code (pragma), but also set a safe default:
set(BEDROCK_FP_FLAGS "")
if (CMAKE_C_COMPILER_ID MATCHES "Clang|GNU")
  list(APPEND BEDROCK_FP_FLAGS "-ffp-contract=off")
endif()

# Optimization flags (Release)
# Note: CMake already adds -O3 for Release on many toolchains,
# but we make it explicit to avoid surprises.
set(BEDROCK_OPT_FLAGS "")
if (CMAKE_BUILD_TYPE STREQUAL "Release")
  if (CMAKE_C_COMPILER_ID MATCHES "Clang|GNU")
    list(APPEND BEDROCK_OPT_FLAGS "-O3")
  endif()
endif()

# Optional native
if (BEDROCK_ENABLE_NATIVE)
  if (CMAKE_C_COMPILER_ID MATCHES "Clang|GNU")
    list(APPEND BEDROCK_OPT_FLAGS "-march=native")
  endif()
endif()

# Optional LTO
if (BEDROCK_ENABLE_LTO)
  include(CheckIPOSupported)
  check_ipo_supported(RESULT ipo_supported OUTPUT ipo_msg)
  if (ipo_supported)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
  else()
    message(WARNING "LTO requested but not supported: ${ipo_msg}")
  endif()
endif()

# -----------------------------
# Sources
# -----------------------------
set(BEDROCK_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include)
include_directories(${BEDROCK_INCLUDE_DIR})

# Common
set(BEDROCK_COMMON
  src/common/bedrock_text.c
  src/common/bedrock_alloc.c
  src/common/bedrock_prng.c
  src/common/bedrock_json.c
)

# Platform (Linux)
set(BEDROCK_PLATFORM
  platform/linux/bedrock_linux_time.c
  platform/linux/bedrock_linux_pin.c
  platform/linux/bedrock_linux_env.c
)

# Bench
set(BEDROCK_BENCH
  src/bench/main.c
  src/bench/bench_spec_v1.c
  src/bench/dot_f32_scalar.c
  src/bench/dot_f32_avx2.c
)

# -----------------------------
# Target
# -----------------------------
add_executable(bedrock_bench
  ${BEDROCK_COMMON}
  ${BEDROCK_PLATFORM}
  ${BEDROCK_BENCH}
)

target_include_directories(bedrock_bench PRIVATE ${BEDROCK_INCLUDE_DIR})
target_compile_options(bedrock_bench PRIVATE
  ${BEDROCK_WARN_FLAGS}
  ${BEDROCK_FP_FLAGS}
  ${BEDROCK_OPT_FLAGS}
)

# AVX2: compile-time guarded in code, but we may still want -mavx2 for maximal codegen.
# IMPORTANT: keep it optional and safe:
# - If compiler doesn't support it, build still succeeds because code guards fallback to scalar.
if (CMAKE_C_COMPILER_ID MATCHES "Clang|GNU")
  target_compile_options(bedrock_bench PRIVATE "-mavx2")
endif()

# Link math if needed
target_link_libraries(bedrock_bench PRIVATE m)

# -----------------------------
# Install (optional)
# -----------------------------
install(TARGETS bedrock_bench DESTINATION bin)

message(STATUS "BEDROCK_ENABLE_LTO=${BEDROCK_ENABLE_LTO}")
message(STATUS "BEDROCK_ENABLE_NATIVE=${BEDROCK_ENABLE_NATIVE}")
message(STATUS "BEDROCK_WERROR=${BEDROCK_WERROR}")
