#ifndef __UC_UTILS
#define __UC_UTILS

#include "uc_extern_sizes.h"

#include <stdint.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

#if !defined(__cplusplus) && __STDC_VERSION__ <= 201710L
#if __STDC_VERSION__ >= 199901L
#include <stdbool.h>
#else
typedef char bool;
#define false 0
#define true 1
#endif
#endif

#if defined(__cplusplus)
#define zig_extern extern "C"
#else
#define zig_extern extern
#endif

#if defined(__has_attribute)
#define zig_has_attribute(attribute) __has_attribute(attribute)
#else
#define zig_has_attribute(attribute) 0
#endif

#if __STDC_VERSION__ >= 201112L
#define zig_align(alignment) _Alignas(alignment)
#elif zig_has_attribute(aligned)
#define zig_align(alignment) __attribute__((aligned(alignment)))
#elif _MSC_VER
#define zig_align(alignment) __declspec(align(alignment))
#else
#define zig_align zig_align_unavailable
#endif

#define uc_opaque(name, size, align)      \
    typedef struct name                   \
    {                                     \
        uint8_t zig_align(align) _[size]; \
    } name;

#endif
