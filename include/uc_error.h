#ifndef __UC_ERROR
#define __UC_ERROR

#include "uc_utils.h"

#define UC_RESULT_SUCCESS 0
#if ERROR_SIZE == 1 && ERROR_ALIGN == 1
typedef int8_t uc_result;
#elif ERROR_SIZE == 2 && ERROR_ALIGN == 2
typedef int16_t uc_result;
#elif ERROR_SIZE == 4 && ERROR_ALIGN == 4
typedef int32_t uc_result;
#elif ERROR_SIZE == 8 && ERROR_ALIGN == 8
typedef int64_t uc_result;
#else
#error "Unsupported error type"
#endif

zig_extern uc_result ucGetAllErrors(uc_result *values, char **names);
zig_extern const char *ucErrorName(const uc_result err);
zig_extern bool ucErrorHasName(const uc_result err, const char *name, const size_t len);
#endif
