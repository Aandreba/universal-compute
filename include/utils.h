#include <stdint.h>

#if defined(__cplusplus)
#define zig_extern extern "C"
#else
#define zig_extern extern
#endif

#define uc_opaque(name) typedef struct name name

typedef struct {
    size_t size;
    size_t align;
} uc_alloc_layout_t;
