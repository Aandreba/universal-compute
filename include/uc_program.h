#ifndef __UC_PROGRAM
#define __UC_PROGRAM

#include "uc_context.h"
#include "uc_error.h"
// #include "uc_event.h"
#include "uc_utils.h"

uc_opaque(uc_program, PROGRAM_SIZE, PROGRAM_ALIGN);
uc_opaque(uc_symbol, SYMBOL_SIZE, SYMBOL_ALIGN);

typedef uint16_t uc_int_bits;
#define UC_INT_BITS_8 (uc_int_bits)8
#define UC_INT_BITS_16 (uc_int_bits)16
#define UC_INT_BITS_32 (uc_int_bits)32
#define UC_INT_BITS_128 (uc_int_bits)128
#define UC_INT_BITS_256 (uc_int_bits)256

typedef uint16_t uc_float_bits;
#define UC_FLOAT_BITS_16 (uc_float_bits)16
#define UC_FLOAT_BITS_32 (uc_float_bits)32
#define UC_FLOAT_BITS_32 (uc_float_bits)64

zig_extern uc_result ucOpenProgram(uc_context* context, const uint8_t* path, size_t path_len, uc_program* program);
zig_extern uc_result ucProgramSymbol(uc_program* program, const uint8_t* name, size_t name_len, uc_symbol* symbol);
zig_extern uc_result ucProgramDeinit(uc_program* program);

zig_extern uc_result ucSymbolSetInteger(uc_symbol* symbol, bool signed, uc_int_bits bits, const void* value);
zig_extern uc_result ucSymbolSetFloat(uc_symbol* symbol, uc_float_bits bits, const void* value);
zig_extern uc_result ucSymbolDeinit(uc_symbol* symbol);

// zig_extern uc_result ucCreateBuffer(uc_context *context, size_t size, const uc_buffer_config *config, uc_buffer *buffer);
// zig_extern uc_result ucBufferRead(uc_buffer *buffer, size_t offset, size_t len, void *dst, uc_event *event);
// zig_extern uc_result ucBufferWrite(uc_buffer *buffer, size_t offset, size_t len, const void *src, uc_event *event);
// zig_extern uc_result ucBufferCopy(uc_buffer *src, size_t src_offset, uc_buffer *dst, size_t dst_offset, size_t len, uc_event *event);
// zig_extern uc_result ucBufferDeinit(uc_buffer *buffer);

#endif
