#include <stdint.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

#define DEVICE_SIZE 2 * sizeof(size_t)
#define DEVICE_ALIGN sizeof(size_t)

#define CONTEXT_SIZE 3 * sizeof(size_t)
#define CONTEXT_ALIGN sizeof(size_t)

#define BUFFER_SIZE 3 * sizeof(size_t)
#define BUFFER_ALIGN sizeof(size_t)
