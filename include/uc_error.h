#ifndef __UC_ERROR
#define __UC_ERROR
#include "uc_utils.h"

typedef int32_t uc_result;
#define UC_RESULT_SUCCESS 0

zig_extern const char *ucErrorName(const uc_result err);
zig_extern bool ucErrorHasName(const uc_result err, const char *name, const size_t len);
#endif
