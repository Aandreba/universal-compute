#ifndef __UC_BUFFER
#define __UC_BUFFER

#include "uc_context.h"
#include "uc_error.h"
#include "uc_event.h"
#include "uc_utils.h"

uc_opaque(uc_buffer, BUFFER_SIZE, BUFFER_ALIGN);
typedef struct uc_buffer_config {
} uc_buffer_config;

typedef size_t uc_buffer_info;
#define UC_BUFFER_INFO_BACKEND (uc_buffer_info)0
#define UC_BUFFER_INFO_DEVICE (uc_buffer_info)1
#define UC_BUFFER_INFO_CONTEXT (uc_buffer_info)2

zig_extern uc_result ucCreateBuffer(uc_context *context, size_t size, const uc_buffer_config *config, uc_buffer *buffer);
zig_extern uc_result ucBufferRead(uc_buffer *buffer, size_t offset, size_t len, void *dst, uc_event *event);
zig_extern uc_result ucBufferWrite(uc_buffer *buffer, size_t offset, size_t len, const void *src, uc_event *event);
zig_extern uc_result ucBufferCopy(uc_buffer *src, size_t src_offset, uc_buffer *dst, size_t dst_offset, size_t len, uc_event *event);
zig_extern uc_result ucBufferDeinit(uc_buffer *buffer);

#endif
