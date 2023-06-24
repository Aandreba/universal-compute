#ifndef __UC_CONTEXT
#define __UC_CONTEXT

#include "device.h"
#include "error.h"
#include "utils.h"

uc_opaque(uc_context, 3 * sizeof(size_t), sizeof(size_t));
typedef struct uc_context_config
{
    bool debug;
} uc_context_config;

uc_result ucCreateContext(uc_device *device, const uc_context_config *config);

#endif
