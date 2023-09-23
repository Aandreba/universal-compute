#ifndef __UC_CONTEXT
#define __UC_CONTEXT

#include "uc_device.h"
#include "uc_error.h"
#include "uc_utils.h"

uc_opaque(uc_context, CONTEXT_SIZE, CONTEXT_ALIGN);
typedef struct uc_context_config {
    bool debug;
} uc_context_config;

typedef size_t uc_context_info;
#define UC_CONTEXT_INFO_BACKEND (uc_context_info)0
#define UC_CONTEXT_INFO_DEVICE (uc_context_info)1

zig_extern uc_result ucCreateContext(uc_device *device, const uc_context_config *config, uc_context *context);
zig_extern uc_result ucContextInfo(const uc_context *context, const uc_context_info info, void *data, size_t *len);
zig_extern uc_result ucContextDeinit(uc_context *context);

#endif
