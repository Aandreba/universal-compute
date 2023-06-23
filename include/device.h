#ifndef UC_DEVICE_SIZE | UC_DEVICE_ALIGN
#error Storage properties for universal compute devices not found
#else

#include <zig.h>

#include "extern_opaque.h"

typedef extern_opaque(UC_DEVICE_SIZE, UC_DEVICE_ALIGN) uc_device_t;

#endif
