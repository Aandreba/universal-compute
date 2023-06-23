#ifndef __UC_ERROR
#define __UC_ERROR
#include "utils.h"

typedef int32_t uc_result_t;
#define UC_RESULT_SUCCESS 0

zig_extern const uint8_t *ucErrorName(const uc_result_t err);
zig_extern bool ucErrorHasName(const uc_result_t err, const uint8_t *name, const size_t len);
#endif
