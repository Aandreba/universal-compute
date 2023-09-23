#ifndef __UC_EVENT
#define __UC_EVENT

#include "uc_error.h"
#include "uc_utils.h"

uc_opaque(uc_event, EVENT_SIZE, EVENT_ALIGN);

typedef size_t uc_event_info;
#define UC_EVENT_INFO_BACKEND (uc_event_info)0

typedef uint32_t uc_event_status;
#define UC_EVENT_STATUS_PENDING (uc_event_status)0
#define UC_EVENT_STATUS_RUNNING (uc_event_status)1
#define UC_EVENT_STATUS_COMPLETE (uc_event_status)2

zig_extern uc_result ucEventJoin(uc_event *event);
zig_extern uc_result ucEventOnComplete(uc_event *event, void (*callback)(uc_result, void *), void *user_data);
zig_extern uc_result ucEventRetain(uc_event *event);
zig_extern uc_result ucEventRelease(uc_event *event);

#endif
