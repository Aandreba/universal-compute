#include <zig.h>

#include "error.h"
#include "utils.h"

uc_opaque(uc_device_t);
typedef unsigned int uc_backend_t;

#define UC_BACKEND_HOST 0
#define UC_BACKEND_OPENCL 1

zig_extern uc_alloc_layout_t ucGetDeviceLayout();
zig_extern uc_result_t ucGetDevices(const uc_backend_t *backends, size_t const backend_len, uc_device_t *devices, size_t *devices_len);
zig_extern uc_result_t ucDeviceInfo(const uc_device_t *device, uint32_t const a1, void *const a2, uintptr_t *const a3);
zig_extern uc_result_t ucDeviceDeinit(uc_device_t *device);
