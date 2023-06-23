#ifndef __UC_UC_EXTERN_OPAQUE
#define __UC_UC_EXTERN_OPAQUE

#include <zig.h>
#define extern_opaque(size, align) \
    struct {                       \
        uint8_t _[size]            \
    } zig_align(align)
#endif
