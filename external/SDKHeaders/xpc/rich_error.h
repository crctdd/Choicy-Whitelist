#ifndef __XPC_RICH_ERROR_H__
#define __XPC_RICH_ERROR_H__

#ifndef __XPC_INDIRECT__
#error "Please #include <xpc/xpc.h> instead of this file directly."

#include <xpc/base.h>
#endif

#ifndef __BLOCKS__
#error "XPC Rich Errors require Blocks support."
#endif

XPC_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS

#pragma mark Properties

XPC_EXPORT XPC_WARN_RESULT
char * _Nullable
xpc_rich_error_copy_description(xpc_rich_error_t error);

XPC_EXPORT XPC_WARN_RESULT
bool
xpc_rich_error_can_retry(xpc_rich_error_t error);

__END_DECLS
XPC_ASSUME_NONNULL_END

#endif
