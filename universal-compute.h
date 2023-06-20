#include "zig.h"

typedef struct uc_device_t __attribute__((aligned(8)));

zig_extern uintptr_t ucErrorName(int32_t const a0, uint8_t *const a1, uintptr_t const a2);
zig_extern int32_t ucGetDevices(uint32_t const *const a0, uintptr_t const a1, uc_device_t a2, uintptr_t const a3);
zig_extern int32_t ucDeviceDeinit(uc_device_t a0);
