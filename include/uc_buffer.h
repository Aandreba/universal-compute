#ifndef __UC_BUFFER
#define __UC_BUFFER

#include "uc_error.h"
#include "uc_context.h"
#include "uc_utils.h"

uc_opaque(uc_buffer, BUFFER_SIZE, BUFFER_ALIGN);
typedef struct uc_buffer_config
{
} uc_buffer_config;

typedef size_t uc_buffer_info;
#define UC_BUFFER_INFO_BACKEND 0
#define UC_BUFFER_INFO_DEVICE 1
#define UC_BUFFER_INFO_CONTEXT 2

zig_extern uc_result ucCreateBuffer(uc_context *context, size_t size, const uc_buffer_config *config, uc_buffer *buffer);
zig_extern uc_result ucBufferRead(const uc_buffer *buffer);
zig_extern uc_result ucBufferDeinit(uc_buffer *buffer);

#endif
