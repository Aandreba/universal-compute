#ifndef __UC_DEVICE
#define __UC_DEVICE

#include "uc_error.h"
#include "uc_utils.h"

uc_opaque(uc_device, DEVICE_SIZE, DEVICE_ALIGN);

typedef size_t uc_backend;
#define UC_BACKEND_HOST 0
#define UC_BACKEND_OPENCL 1

typedef size_t uc_device_info;
#define UC_DEVICE_INFO_BACKEND 0
#define UC_DEVICE_INFO_VENDOR 1
#define UC_DEVICE_INFO_NAME 2
#define UC_DEVICE_INFO_CORE_COUNT 3
#define UC_DEVICE_INFO_MAX_FREQUENCY 4

zig_extern const char *ucBackendName(const uc_backend backend);
zig_extern uc_result ucGetDevices(const uc_backend *backends, size_t const backend_len, uc_device *devices, size_t *devices_len);
zig_extern uc_result ucDeviceInfo(const uc_device *device, const uc_device_info info, void *data, size_t *len);
zig_extern uc_result ucDeviceDeinit(uc_device *device);

#endif
