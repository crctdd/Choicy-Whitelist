#ifndef __XPC_SESSION_H__
#define __XPC_SESSION_H__

#ifndef __XPC_INDIRECT__
#error "Please #include <xpc/xpc.h> instead of this file directly."
 
#include <xpc/base.h>
#endif  

#ifndef __BLOCKS__
#error "XPC Session require Blocks support."
#endif  

XPC_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS

 














OS_OBJECT_DECL_SENDABLE_CLASS(xpc_session);

#pragma mark Constants
 















XPC_SWIFT_NOEXPORT
XPC_FLAGS_ENUM(xpc_session_create_flags, uint64_t,
	XPC_SESSION_CREATE_NONE XPC_SWIFT_NAME("none") = 0,
	XPC_SESSION_CREATE_INACTIVE XPC_SWIFT_NAME("inactive") = (1 << 0),
	XPC_SESSION_CREATE_MACH_PRIVILEGED XPC_SWIFT_NAME("privileged") = (1 << 1)
);

#pragma mark Handlers
typedef void (^xpc_session_cancel_handler_t)(xpc_rich_error_t error) XPC_SWIFT_NOEXPORT;
typedef void (^xpc_session_incoming_message_handler_t)(xpc_object_t message) XPC_SWIFT_NOEXPORT;
typedef void (^xpc_session_reply_handler_t)(xpc_object_t _Nullable reply,
		xpc_rich_error_t _Nullable error) XPC_SWIFT_NOEXPORT;

#pragma mark Helpers
 











API_AVAILABLE(macos(13.0), ios(16.0), tvos(16.0), watchos(9.0))
XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_WARN_RESULT
char * _Nullable
xpc_session_copy_description(xpc_session_t session);

#pragma mark Client Session Creation
 






























API_AVAILABLE(macos(13.0), macCatalyst(16.0))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_session_t _Nullable
xpc_session_create_xpc_service(const char *name,
		dispatch_queue_t _Nullable target_queue,
		xpc_session_create_flags_t flags,
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

 

































API_AVAILABLE(macos(13.0), macCatalyst(16.0))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_session_t _Nullable
xpc_session_create_mach_service(const char *mach_service,
		dispatch_queue_t _Nullable target_queue,
		xpc_session_create_flags_t flags,
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

#pragma mark Session Configuration
 














API_AVAILABLE(macos(13.0), ios(16.0), tvos(16.0), watchos(9.0))
XPC_EXPORT XPC_SWIFT_NOEXPORT
void
xpc_session_set_incoming_message_handler(xpc_session_t session,
		xpc_session_incoming_message_handler_t handler);

 














API_AVAILABLE(macos(13.0), ios(16.0), tvos(16.0), watchos(9.0))
XPC_EXPORT XPC_SWIFT_NOEXPORT
void
xpc_session_set_cancel_handler(xpc_session_t session,
		xpc_session_cancel_handler_t cancel_handler);

 

















API_AVAILABLE(macos(14.0), ios(17.0), tvos(17.0), watchos(10.0))
XPC_EXPORT XPC_SWIFT_NOEXPORT
void
xpc_session_set_target_queue(xpc_session_t session,
		dispatch_queue_t _Nullable target_queue);

#pragma mark Lifecycle
 




















API_AVAILABLE(macos(13.0), ios(16.0), tvos(16.0), watchos(9.0))
XPC_EXPORT XPC_SWIFT_NOEXPORT
bool
xpc_session_activate(xpc_session_t session,
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

 














API_AVAILABLE(macos(13.0), ios(16.0), tvos(16.0), watchos(9.0))
XPC_EXPORT XPC_SWIFT_NOEXPORT
void
xpc_session_cancel(xpc_session_t session);

#pragma mark Message Send
 

























API_AVAILABLE(macos(13.0), ios(16.0), tvos(16.0), watchos(9.0))
XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_rich_error_t _Nullable
xpc_session_send_message(xpc_session_t session, xpc_object_t message);

 



































API_AVAILABLE(macos(13.0), ios(16.0), tvos(16.0), watchos(9.0))
XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t _Nullable
xpc_session_send_message_with_reply_sync(xpc_session_t session,
		xpc_object_t message, xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

 

























API_AVAILABLE(macos(13.0), ios(16.0), tvos(16.0), watchos(9.0))
XPC_EXPORT XPC_SWIFT_NOEXPORT
void
xpc_session_send_message_with_reply_async(xpc_session_t session,
		xpc_object_t message, xpc_session_reply_handler_t reply_handler);

 






























API_AVAILABLE(macos(14.4))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
int
xpc_session_set_peer_code_signing_requirement(xpc_session_t session, const char *requirement);

 





















API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0))

XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_NONNULL_ALL
void
xpc_session_set_peer_requirement(xpc_session_t session, xpc_peer_requirement_t requirement);

 
#define XPC_TYPE_SESSION (&_xpc_type_session)
XPC_EXPORT
XPC_TYPE(_xpc_type_session);

__END_DECLS
XPC_ASSUME_NONNULL_END

#endif  
