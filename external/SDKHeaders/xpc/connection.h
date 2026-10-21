#ifndef __XPC_CONNECTION_H__
#define __XPC_CONNECTION_H__

#ifndef __XPC_INDIRECT__
#error "Please #include <xpc/xpc.h> instead of this file directly."
 
#include <xpc/base.h>
#endif  

#ifndef __BLOCKS__
#error "XPC connections require Blocks support."
#endif  

XPC_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS

 
















#define XPC_ERROR_CONNECTION_INTERRUPTED \
	XPC_GLOBAL_OBJECT(_xpc_error_connection_interrupted)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
const struct _xpc_dictionary_s _xpc_error_connection_interrupted;

 












#define XPC_ERROR_CONNECTION_INVALID \
	XPC_GLOBAL_OBJECT(_xpc_error_connection_invalid)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
const struct _xpc_dictionary_s _xpc_error_connection_invalid;

 
















#define XPC_ERROR_TERMINATION_IMMINENT \
	XPC_GLOBAL_OBJECT(_xpc_error_termination_imminent)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
const struct _xpc_dictionary_s _xpc_error_termination_imminent;

 







#define XPC_ERROR_PEER_CODE_SIGNING_REQUIREMENT \
	XPC_GLOBAL_OBJECT(_xpc_error_peer_code_signing_requirement)
__API_AVAILABLE(macos(12.0), macCatalyst(15.0))
XPC_EXPORT
const struct _xpc_dictionary_s _xpc_error_peer_code_signing_requirement;

 







#define XPC_CONNECTION_MACH_SERVICE_LISTENER (1 << 0)

 







#define XPC_CONNECTION_MACH_SERVICE_PRIVILEGED (1 << 1)

 









typedef void (*xpc_finalizer_t)(void * _Nullable value);

 

































__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_connection_t
xpc_connection_create(const char * _Nullable name,
	dispatch_queue_t _Nullable targetq);

 
































API_AVAILABLE(macos(10.7), macCatalyst(5.0))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
xpc_connection_t
xpc_connection_create_mach_service(const char *name,
	dispatch_queue_t _Nullable targetq, uint64_t flags);

 
















__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_connection_t
xpc_connection_create_from_endpoint(xpc_endpoint_t endpoint);

 

































__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_connection_set_target_queue(xpc_connection_t connection,
	dispatch_queue_t _Nullable targetq);

 


































































__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
void
xpc_connection_set_event_handler(xpc_connection_t connection,
	XPC_SWIFT_SENDABLE xpc_handler_t handler);

 


















__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0)
__TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0)
XPC_EXPORT XPC_NONNULL_ALL
void
xpc_connection_activate(xpc_connection_t connection);

 





















__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
void
xpc_connection_suspend(xpc_connection_t connection);

 



















__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
void
xpc_connection_resume(xpc_connection_t connection);

 






























__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
void
xpc_connection_send_message(xpc_connection_t connection, xpc_object_t message);

 













































__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
void
xpc_connection_send_barrier(xpc_connection_t connection,
	dispatch_block_t barrier);

 































__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2 XPC_NONNULL4
void
xpc_connection_send_message_with_reply(xpc_connection_t connection,
	xpc_object_t message, dispatch_queue_t _Nullable replyq,
	XPC_SWIFT_SENDABLE xpc_handler_t handler);

 































__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT XPC_RETURNS_RETAINED
xpc_object_t
xpc_connection_send_message_with_reply_sync(xpc_connection_t connection,
	xpc_object_t message);

 























__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
void
xpc_connection_cancel(xpc_connection_t connection);

 










__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
const char * _Nullable
xpc_connection_get_name(xpc_connection_t connection);

 









__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
uid_t
xpc_connection_get_euid(xpc_connection_t connection);

 









__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
gid_t
xpc_connection_get_egid(xpc_connection_t connection);

 




















API_AVAILABLE(macos(10.7))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
pid_t
xpc_connection_get_pid(xpc_connection_t connection);

 









API_AVAILABLE(macos(10.7))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
au_asid_t
xpc_connection_get_asid(xpc_connection_t connection);

 



















__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_connection_set_context(xpc_connection_t connection,
	void * _Nullable context);

 










__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
void * _Nullable
xpc_connection_get_context(xpc_connection_t connection);

 



















__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_connection_set_finalizer_f(xpc_connection_t connection,
	xpc_finalizer_t _Nullable finalizer);

 



























__API_AVAILABLE(macos(12.0), macCatalyst(15.0))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
int
xpc_connection_set_peer_code_signing_requirement(xpc_connection_t connection, const char *requirement);

 

























API_AVAILABLE(macos(14.4), ios(17.4), tvos(17.4), watchos(10.4))

XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
int
xpc_connection_set_peer_entitlement_exists_requirement(xpc_connection_t connection, const char *entitlement);

 































API_AVAILABLE(macos(14.4), ios(17.4), tvos(17.4), watchos(10.4))

XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
int
xpc_connection_set_peer_entitlement_matches_value_requirement(xpc_connection_t connection, const char *entitlement, xpc_object_t value);

 






























API_AVAILABLE(macos(14.4), ios(17.4), tvos(17.4), watchos(10.4))

XPC_EXPORT XPC_NONNULL1 XPC_WARN_RESULT
int
xpc_connection_set_peer_team_identity_requirement(xpc_connection_t connection, const char * _Nullable signing_identifier);

 




























API_AVAILABLE(macos(14.4), ios(17.4), tvos(17.4), watchos(10.4))

XPC_EXPORT XPC_NONNULL1 XPC_WARN_RESULT
int
xpc_connection_set_peer_platform_identity_requirement(xpc_connection_t connection, const char * _Nullable signing_identifier);

 









































API_AVAILABLE(macos(14.4), ios(17.4), tvos(17.4), watchos(10.4))

XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
int
xpc_connection_set_peer_lightweight_code_requirement(xpc_connection_t connection, xpc_object_t lwcr);

 



















API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0))

XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_NONNULL_ALL
void
xpc_connection_set_peer_requirement(xpc_connection_t connection,
		xpc_peer_requirement_t peer_requirement);

 









API_AVAILABLE(macos(12.0), ios(15.0), tvos(15.0), watchos(8.0))
XPC_EXPORT XPC_NONNULL1 XPC_WARN_RESULT
char * _Nullable
xpc_connection_copy_invalidation_reason(xpc_connection_t connection);

__END_DECLS
XPC_ASSUME_NONNULL_END

#endif  
