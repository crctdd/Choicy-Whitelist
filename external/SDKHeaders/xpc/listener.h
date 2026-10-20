#ifndef __XPC_LISTENER_H__
#define __XPC_LISTENER_H__

#ifndef __XPC_INDIRECT__
#error "Please #include <xpc/xpc.h> instead of this file directly."

#include <xpc/base.h>
#endif

#ifndef __BLOCKS__
#error "XPC Listener require Blocks support."
#endif

XPC_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS

OS_OBJECT_DECL_SENDABLE_CLASS(xpc_listener);

#pragma mark Constants

XPC_SWIFT_NOEXPORT
XPC_FLAGS_ENUM(xpc_listener_create_flags, uint64_t,
	XPC_LISTENER_CREATE_NONE XPC_SWIFT_NAME("none") = 0,
	XPC_LISTENER_CREATE_INACTIVE XPC_SWIFT_NAME("inactive") = (1 << 0),
	XPC_LISTENER_CREATE_FORCE_MACH XPC_SWIFT_NAME("mach") = ( 1 << 1),
	XPC_LISTENER_CREATE_FORCE_XPCSERVICE XPC_SWIFT_NAME("xpcservice") = ( 1 << 2),
);

#pragma mark Handlers
typedef void (^xpc_listener_incoming_session_handler_t)(xpc_session_t peer);

#pragma mark Helpers

API_AVAILABLE(macos(14.0), macCatalyst(17.0))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_WARN_RESULT
char * _Nullable
xpc_listener_copy_description(xpc_listener_t listener);

#pragma mark Server Session Creation

API_AVAILABLE(macos(14.0), macCatalyst(17.0))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_listener_t _Nullable
xpc_listener_create(const char * service,
		dispatch_queue_t _Nullable target_queue,
		xpc_listener_create_flags_t flags,
		xpc_listener_incoming_session_handler_t incoming_session_handler,
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

#pragma mark Lifecycle

API_AVAILABLE(macos(14.0), macCatalyst(17.0))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_SWIFT_NOEXPORT
bool
xpc_listener_activate(xpc_listener_t listener,
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

API_AVAILABLE(macos(14.0), macCatalyst(17.0))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_SWIFT_NOEXPORT
void
xpc_listener_cancel(xpc_listener_t listener);

API_AVAILABLE(macos(14.0), macCatalyst(17.0))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_SWIFT_NOEXPORT
void
xpc_listener_reject_peer(xpc_session_t peer, const char *reason);

API_AVAILABLE(macos(14.4))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
int
xpc_listener_set_peer_code_signing_requirement(xpc_listener_t listener, const char *requirement);

API_AVAILABLE(macos(26.0), ios(26.0))
API_UNAVAILABLE(tvos, watchos)
XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_NONNULL_ALL
void
xpc_listener_set_peer_requirement(xpc_listener_t listener, xpc_peer_requirement_t requirement);

__END_DECLS
XPC_ASSUME_NONNULL_END

#endif
