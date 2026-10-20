#ifndef __XPC_ACTIVITY_H__
#define __XPC_ACTIVITY_H__

#ifndef __XPC_INDIRECT__
#error "Please #include <xpc/xpc.h> instead of this file directly."

#include <xpc/base.h>
#endif

#ifdef __BLOCKS__

XPC_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const char * const XPC_ACTIVITY_INTERVAL;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const char * const XPC_ACTIVITY_REPEATING;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const char * const XPC_ACTIVITY_DELAY;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const char * const XPC_ACTIVITY_GRACE_PERIOD;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_1_MIN;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_5_MIN;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_15_MIN;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_30_MIN;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_1_HOUR;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_4_HOURS;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_8_HOURS;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_1_DAY;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_7_DAYS;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const char * const XPC_ACTIVITY_PRIORITY;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const char * const XPC_ACTIVITY_PRIORITY_MAINTENANCE;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const char * const XPC_ACTIVITY_PRIORITY_UTILITY;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const char * const XPC_ACTIVITY_ALLOW_BATTERY;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const char * const XPC_ACTIVITY_REQUIRE_SCREEN_SLEEP;

API_AVAILABLE(macos(12.0))
API_UNAVAILABLE(ios, watchos)
XPC_EXPORT
const char * const XPC_ACTIVITY_PREVENT_DEVICE_SLEEP;

__OSX_AVAILABLE_BUT_DEPRECATED_MSG(__MAC_10_9, __MAC_10_9, __IPHONE_7_0, __IPHONE_7_0,
	"REQUIRE_BATTERY_LEVEL is not implemented")
XPC_EXPORT
const char * const XPC_ACTIVITY_REQUIRE_BATTERY_LEVEL;

__OSX_AVAILABLE_BUT_DEPRECATED_MSG(__MAC_10_9, __MAC_10_9, __IPHONE_7_0, __IPHONE_7_0,
	"REQUIRE_HDD_SPINNING is not implemented")
XPC_EXPORT
const char * const XPC_ACTIVITY_REQUIRE_HDD_SPINNING;

#define XPC_TYPE_ACTIVITY (&_xpc_type_activity)
API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
XPC_TYPE(_xpc_type_activity);

XPC_DECL(xpc_activity);

XPC_NONNULL1
typedef void (^xpc_activity_handler_t)(xpc_activity_t activity);

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios)
XPC_EXPORT
const xpc_object_t XPC_ACTIVITY_CHECK_IN;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2 XPC_NONNULL3
void
xpc_activity_register(const char *identifier, xpc_object_t criteria,
	xpc_activity_handler_t handler);

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_WARN_RESULT XPC_RETURNS_RETAINED XPC_NONNULL1
xpc_object_t _Nullable
xpc_activity_copy_criteria(xpc_activity_t activity);

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_activity_set_criteria(xpc_activity_t activity, xpc_object_t criteria);

enum {
	XPC_ACTIVITY_STATE_CHECK_IN,
	XPC_ACTIVITY_STATE_WAIT,
	XPC_ACTIVITY_STATE_RUN,
	XPC_ACTIVITY_STATE_DEFER,
	XPC_ACTIVITY_STATE_CONTINUE,
	XPC_ACTIVITY_STATE_DONE,
};
typedef long xpc_activity_state_t;

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
xpc_activity_state_t
xpc_activity_get_state(xpc_activity_t activity);

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
bool
xpc_activity_set_state(xpc_activity_t activity, xpc_activity_state_t state);

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
bool
xpc_activity_should_defer(xpc_activity_t activity);

API_AVAILABLE(macos(10.9))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_NONNULL1
void
xpc_activity_unregister(const char *identifier);

__END_DECLS
XPC_ASSUME_NONNULL_END

#endif

#endif

