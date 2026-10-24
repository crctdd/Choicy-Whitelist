// Copyright (c) 2009-2020 Apple Inc. All rights reserved. 

#ifndef __XPC_H__
#define __XPC_H__

#include <os/object.h>
                                                                            
#ifndef OS_OBJECT_DECL_SENDABLE_CLASS
#define OS_OBJECT_DECL_SENDABLE_CLASS(name) OS_OBJECT_DECL_CLASS(name)
#endif
#include <dispatch/dispatch.h>

#include <sys/mman.h>
#include <uuid/uuid.h>
#include <bsm/audit.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

#ifndef __XPC_INDIRECT__
#define __XPC_INDIRECT__
#endif                    

#include <xpc/base.h>

#if __has_include(<xpc/xpc_transaction_deprecate.h>)
#include <xpc/xpc_transaction_deprecate.h>
#else                                                
#define XPC_TRANSACTION_DEPRECATED
#endif                                                

XPC_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS

#ifndef __OSX_AVAILABLE_STARTING
#define __OSX_AVAILABLE_STARTING(x, y)
#endif                            

#define XPC_API_VERSION 20200610

   
                      
                                          
   
typedef const struct _xpc_type_s * xpc_type_t;
#ifndef XPC_TYPE
#define XPC_TYPE(type) const struct _xpc_type_s type
#endif            

   
                        
                                                                                
                                  
  
                                                                            
                                                                                
          
   

#if OS_OBJECT_USE_OBJC
                                                                               
                                                                         
                                                                       
                                                               
  
                                 
   
OS_OBJECT_DECL(xpc_object);
#ifndef XPC_DECL
#define XPC_DECL(name) typedef xpc_object_t name##_t
#endif            

#define XPC_GLOBAL_OBJECT(object) ((OS_OBJECT_BRIDGE xpc_object_t)&(object))
#define XPC_RETURNS_RETAINED OS_OBJECT_RETURNS_RETAINED
XPC_INLINE XPC_NONNULL_ALL
void
_xpc_object_validate(xpc_object_t object) {
	(void)*(unsigned long volatile *)(OS_OBJECT_BRIDGE void *)object;
}
#else                      
typedef void * xpc_object_t;
#define XPC_DECL(name) typedef struct _##name##_s * name##_t
#define XPC_GLOBAL_OBJECT(object) (&(object))
#define XPC_RETURNS_RETAINED
#endif                       

   
                         
                                                                 
  
                
                                                                               
                                                                        
                                       
  
              
                                                          
   
#if __BLOCKS__
typedef void (^xpc_handler_t)(xpc_object_t object);
#endif               

   
                              
                                                                          
                                                                     
                                                                     
   
#define XPC_TYPE_CONNECTION (&_xpc_type_connection)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_connection);
XPC_DECL(xpc_connection);

   
                                    
                                                                               
                                            
  
                    
                                                                                
                                                                             
                                                     
   
typedef void (*xpc_connection_handler_t)(xpc_connection_t connection);

   
                            
                                                                               
                                                                      
                                                                              
                                               
                                                                               
               
   
#define XPC_TYPE_ENDPOINT (&_xpc_type_endpoint)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_endpoint);
XPC_DECL(xpc_endpoint);

   
                        
                                                                            
                                                                              
                                                                              
                      
   
#define XPC_TYPE_NULL (&_xpc_type_null)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_null);

   
                        
                                       
   
#define XPC_TYPE_BOOL (&_xpc_type_bool)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_bool);

   
                        
                                                                             
                                                       
   
#define XPC_BOOL_TRUE XPC_GLOBAL_OBJECT(_xpc_bool_true)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
const struct _xpc_bool_s _xpc_bool_true;

   
                         
                                                                              
                                                       
   
#define XPC_BOOL_FALSE XPC_GLOBAL_OBJECT(_xpc_bool_false)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
const struct _xpc_bool_s _xpc_bool_false;

   
                         
                                                      
   
#define XPC_TYPE_INT64 (&_xpc_type_int64)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_int64);

   
                          
                                                         
   
#define XPC_TYPE_UINT64 (&_xpc_type_uint64)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_uint64);

   
                          
                                                                                
   
#define XPC_TYPE_DOUBLE (&_xpc_type_double)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_double);

   
                        
                                                                           
                                                                            
                   
   
#define XPC_TYPE_DATE (&_xpc_type_date)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_date);

   
                        
                                                    
   
#define XPC_TYPE_DATA (&_xpc_type_data)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_data);

   
                          
                                                 
   
#define XPC_TYPE_STRING (&_xpc_type_string)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_string);

   
                        
                                                                             
   
#define XPC_TYPE_UUID (&_xpc_type_uuid)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_uuid);

   
                      
                                               
   
#define XPC_TYPE_FD (&_xpc_type_fd)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_fd);

   
                         
                                                 
   
#define XPC_TYPE_SHMEM (&_xpc_type_shmem)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_shmem);

   
                         
                                                                              
                                                                          
                                                                           
                            
   
#define XPC_TYPE_ARRAY (&_xpc_type_array)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_array);

   
                              
                                                                           
                                                                            
                                                 
   
#define XPC_TYPE_DICTIONARY (&_xpc_type_dictionary)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_dictionary);

   
                         
                                                                           
                                                                       
                                                                               
                                                                                
                                              
  
                                                                                
                                                                           
                                                                            
                             
   
#define XPC_TYPE_ERROR (&_xpc_type_error)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_error);

   
                                    
                                                                            
                                                    
   
#define XPC_ERROR_KEY_DESCRIPTION _xpc_error_key_description
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
const char * const _xpc_error_key_description;

   
                             
                                                                          
                                   
   
#define XPC_EVENT_KEY_NAME _xpc_event_key_name
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
const char * const _xpc_event_key_name;

   
                              
  
              
                                                                               
                              
   
#define XPC_TYPE_RICH_ERROR (&_xpc_type_rich_error)
XPC_EXPORT
XPC_TYPE(_xpc_type_rich_error);
XPC_DECL(xpc_rich_error);

__END_DECLS
XPC_ASSUME_NONNULL_END
#if !defined(__XPC_BUILDING_XPC__) || !__XPC_BUILDING_XPC__
#include <xpc/endpoint.h>
#include <xpc/debug.h>
#if __BLOCKS__
#include <xpc/activity.h>
#include <xpc/peer_requirement.h>
#include <xpc/connection.h>
#include <xpc/rich_error.h>
#include <xpc/session.h>
#include <xpc/listener.h>
#endif              
#undef __XPC_INDIRECT__
#if __has_include(<launch.h>)
#include <launch.h>
#endif                             
#endif                                                           
XPC_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS

#pragma mark XPC Object Protocol
   
                       
  
            
                                               
  
                
                                         
  
          
                              
  
              
                                                                     
                           
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
xpc_object_t
xpc_retain(xpc_object_t object);
#if OS_OBJECT_USE_OBJC_RETAIN_RELEASE
#undef xpc_retain
#define xpc_retain(object) ({ xpc_object_t _o = (object); \
		_xpc_object_validate(_o); [_o retain]; })
#endif                                     

   
                        
  
            
                                               
  
                
                                         
  
              
                                                                              
                                                                              
                                                                                
                             
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_release(xpc_object_t object);
#if OS_OBJECT_USE_OBJC_RETAIN_RELEASE
#undef xpc_release
#define xpc_release(object) ({ xpc_object_t _o = (object); \
		_xpc_object_validate(_o); [_o release]; })
#endif                                     

   
                         
  
            
                                 
  
                
                         
  
          
                                                                                
                                                                           
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
xpc_type_t
xpc_get_type(xpc_object_t object);

   
                              
  
            
                                                  
  
              
                        
  
          
                                                                       
                                               
   
__OSX_AVAILABLE_STARTING(__MAC_10_15, __IPHONE_13_0)
XPC_EXPORT XPC_NONNULL1
const char *
xpc_type_get_name(xpc_type_t type);

   
                     
  
            
                                
  
                
                      
  
          
                                                                         
                                                                            
                       
  
              
                                                                              
  
                                                                            
                                                                              
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT XPC_RETURNS_RETAINED
xpc_object_t _Nullable
xpc_copy(xpc_object_t object);

   
                      
  
            
                                     
  
                 
                               
  
                 
                                
  
          
                                                                              
                                         
  
                                                                       
                                                                             
                            
  
                                                                                
                  
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2 XPC_WARN_RESULT
bool
xpc_equal(xpc_object_t object1, xpc_object_t object2);

   
                     
  
            
                                                
  
                
                                                                           
                                                                         
  
          
                             
  
              
                                                                             
                                                                    
                                                                           
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_WARN_RESULT
size_t
xpc_hash(xpc_object_t object);

   
                                 
  
            
                                               
  
                
                                      
  
          
                                                                              
                                                            
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_WARN_RESULT XPC_NONNULL1
char *
xpc_copy_description(xpc_object_t object);

#pragma mark XPC Object Types
#pragma mark Null
   
                            
  
            
                                                      
  
          
                     
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_null_create(void);

#pragma mark Boolean
   
                            
  
            
                                 
  
               
                                                    
  
          
                        
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_bool_create(bool value);

   
                               
  
            
                                                        
  
               
                                              
  
          
                                                                           
                  
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
bool
xpc_bool_get_value(xpc_object_t xbool);

#pragma mark Signed Integer
   
                             
  
            
                                        
  
               
                                                 
  
          
                               
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_int64_create(int64_t value);

   
                                
  
            
                                                                     
  
              
                                                     
  
          
                                                                             
                  
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
int64_t
xpc_int64_get_value(xpc_object_t xint);

#pragma mark Unsigned Integer
   
                              
  
            
                                          
  
               
                                                   
  
          
                                 
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_uint64_create(uint64_t value);

   
                                 
  
            
                                                                       
  
               
                                                       
  
          
                                                                                
                           
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
uint64_t
xpc_uint64_get_value(xpc_object_t xuint);

#pragma mark Double
   
                              
  
            
                                
  
               
                                                    
  
          
                               
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_double_create(double value);

   
                                 
  
            
                                                                               
  
                 
                                                     
  
          
                                                                                
                         
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
double
xpc_double_get_value(xpc_object_t xdouble);

#pragma mark Date
   
                            
  
            
                              
  
                  
                                                                              
                                                                          
                                                                               
                                                                                 
  
          
                     
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_date_create(int64_t interval);

   
                                         
  
            
                                                            
  
          
                                                   
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_date_create_from_current(void);

   
                               
  
            
                                                       
  
               
                                           
  
          
                                                                            
                                                                           
                                                                
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
int64_t
xpc_date_get_value(xpc_object_t xdate);

#pragma mark Data
   
                            
  
            
                                                      
  
               
                                                                                
                                                                             
                                                      
  
                
                                             
  
          
                     
  
              
                                                                              
                                                          
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_data_create(const void * _Nullable XPC_SIZEDBY(length) bytes, size_t length);

   
                                               
  
            
                                                                                
               
  
               
                                                                              
                                  
  
          
                     
  
              
                                                                          
                                                                        
                                           
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
xpc_object_t
xpc_data_create_with_dispatch_data(dispatch_data_t ddata);

   
                                
  
            
                                                                     
  
               
                                           
  
          
                                                                              
                   
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
size_t
xpc_data_get_length(xpc_object_t xdata);

   
                                   
  
            
                                                              
  
               
                                           
  
          
                                                                                
                   
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
const void * _Nullable
xpc_data_get_bytes_ptr(xpc_object_t xdata);

   
                               
  
            
                                                                      
  
               
                                           
  
                
                                                       
  
             
                                                                            
                                                                          
                                  
  
                
                                        
  
          
                                                                                
                              
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1 XPC_NONNULL2
size_t
xpc_data_get_bytes(xpc_object_t xdata, 
	void *buffer, size_t off, size_t length);

#pragma mark String
   
                              
  
            
                                                                
  
                
                                     
  
          
                       
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
xpc_object_t
xpc_string_create(const char *string);

   
                                          
  
            
                                                                           
                                     
  
             
                                                                               
               
  
             
                                                                          
  
          
                       
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
XPC_PRINTF(1, 2)
xpc_object_t
xpc_string_create_with_format(const char *fmt, ...);

   
                                                        
  
            
                                                                           
                                                 
  
             
                                                                               
               
  
            
                                                                               
          
  
          
                       
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
XPC_PRINTF(1, 0)
xpc_object_t
xpc_string_create_with_format_and_arguments(const char *fmt, va_list ap);

   
                                  
  
            
                                               
  
                 
                                             
  
          
                                                                              
                                                    
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
size_t
xpc_string_get_length(xpc_object_t xstring);

   
                                      
  
            
                                                                
  
                 
                                             
  
          
                                                                                
                                
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
const char * _Nullable
xpc_string_get_string_ptr(xpc_object_t xstring);

#pragma mark UUID
   
                            
  
            
                                                                               
                        
  
              
                                 
  
          
                     
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
xpc_object_t
xpc_uuid_create(const uuid_t XPC_NONNULL_ARRAY uuid);

   
                               
  
            
                                                                       
  
               
                                           
   
          
                                                                               
                                                                               
        
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
const uint8_t * _Nullable
xpc_uuid_get_bytes(xpc_object_t xuuid);

#pragma mark File Descriptors
   
                          
  
            
                                                              
  
            
                                            
  
          
                                                                       
                                                           
  
              
                                                                              
                                                                            
                     
  
                                                                              
                                                                             
                                                                              
                                                                           
                                                                           
                                                                    
  
                                                                            
                                                                       
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t _Nullable
xpc_fd_create(int fd);

   
                       
  
            
                                                                            
                          
  
             
                                                      
  
          
                                                                      
                                                                           
                                                         
  
              
                                                                                
                                                                               
                              
  
                                                                             
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
int
xpc_fd_dup(xpc_object_t xfd);

#pragma mark Shared Memory
   
                             
  
            
                                                                     
  
                
                                                                            
                                                  
  
                
                            
  
          
                              
  
              
                                                                          
                                                                            
                                                                            
                                                                               
                               
  
                                                                                
                                                                               
                                                            
  
                                                                              
                                                                                
                                                                             
                                                                        
                                                                            
                                                              
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
xpc_object_t
xpc_shmem_create(void *region, size_t length);

   
                          
  
            
                                                                          
                 
  
                
                                           
  
                
                                                                          
          
  
          
                                                                            
                                                                               
                                                                         
                                                            
  
              
                                                           
  
                                                                          
                       
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
size_t
xpc_shmem_map(xpc_object_t xshmem, void * _Nullable * _Nonnull region);

#pragma mark Array
   
                               
                                                      
  
               
                                      
  
               
                                      
  
          
                                                          
   
#ifdef __BLOCKS__
typedef bool (^xpc_array_applier_t)(size_t index, xpc_object_t _Nonnull value);
#endif               

   
                             
  
            
                                                              
  
              
                                                                           
                                                                           
                           
  
                 
                                                                           
                                                                             
                                                                   
  
               
                                                                              
                                                                               
                                                                           
                                                              
  
          
                       
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_array_create(
	const xpc_object_t _Nonnull *XPC_COUNTEDBY(count) _Nullable objects,
	size_t count);

   
                                   
  
            
                                                              
  
          
                      
  
       
                   
   
API_AVAILABLE(macos(11.0), ios(14.0), tvos(14.0), watchos(7.0))
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_array_create_empty(void);

   
                                
  
            
                                                                      
  
                
                                               
  
               
                                                                               
                                                                              
                                                                 
   
               
                                                                          
                                                                            
                                              
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL3
void
xpc_array_set_value(xpc_object_t xarray, size_t index, xpc_object_t value);

   
                                   
  
            
                                     
  
                
                                               
  
               
                                                              
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_array_append_value(xpc_object_t xarray, xpc_object_t value);

   
                                
  
            
                                                      
  
                
                                            
  
          
                                                                            
         
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
size_t
xpc_array_get_count(xpc_object_t xarray);

   
                                
  
            
                                                         
  
                
                                            
  
               
                                                                            
                                                 
   
          
                                                                          
                               
  
              
                                                                              
                                                                   
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
xpc_object_t
xpc_array_get_value(xpc_object_t xarray, size_t index);

   
                            
  
            
                                                        
  
                
                                            
  
                 
                                                                       
   
          
                                                                              
                                                               
  
              
                                                                                
                         
   
#ifdef __BLOCKS__
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
bool
xpc_array_apply(xpc_object_t xarray, XPC_NOESCAPE xpc_array_applier_t applier);
#endif               

#pragma mark Array Primitive Setters
   
                           
                                                                         
                                                                            
                         
   
#define XPC_ARRAY_APPEND ((size_t)(-1))

   
                               
  
            
                                                               
  
                
                                               
  
               
                                                                               
                                                                                
                                                                           
             
  
               
                                                                            
                                                                               
                                      
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_array_set_bool(xpc_object_t xarray, size_t index, bool value);

   
                                
  
            
                                                                   
  
                
                                               
  
               
                                                                               
                                                                                
                                                                           
             
  
               
                                                                               
                                                                               
                                      
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_array_set_int64(xpc_object_t xarray, size_t index, int64_t value);

   
                                 
  
            
                                                                   
  
                
                                               
  
               
                                                                               
                                                                                
                                                                           
             
  
               
                                                                                
                                                                               
                                      
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_array_set_uint64(xpc_object_t xarray, size_t index, uint64_t value);

   
                                 
  
            
                                                                 
  
                
                                               
  
               
                                                                               
                                                                                
                                                                           
             
  
               
                                                                              
                                                                               
                                      
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_array_set_double(xpc_object_t xarray, size_t index, double value);

   
                               
  
            
                                      
  
                
                                               
  
               
                                                                               
                                                                                
                                                                           
             
  
               
                                                                        
                                                                             
                                                                             
                                                                             
                                                
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_array_set_date(xpc_object_t xarray, size_t index, int64_t value);

   
                               
  
            
                                          
  
                
                                               
  
               
                                                                               
                                                                                
                                                                           
             
  
               
                                                                            
                                                                              
                                                       
  
                
                          
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_array_set_data(xpc_object_t xarray, size_t index,
	const void *XPC_SIZEDBY(length) _Nullable bytes, size_t length);

   
                                 
  
            
                                    
  
                
                                               
  
               
                                                                               
                                                                                
                                                                           
             
  
                
                                                                    
                                                                             
                                 
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL3
void
xpc_array_set_string(xpc_object_t xarray, size_t index, const char *string);

   
                               
  
            
                                                                 
  
                
                                               
  
               
                                                                               
                                                                                
                                                                           
             
  
              
                                                                          
                                                                             
                                 
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL3
void
xpc_array_set_uuid(xpc_object_t xarray, size_t index,
	const uuid_t XPC_NONNULL_ARRAY uuid);

   
                             
  
            
                                           
  
                
                                               
  
               
                                                                               
                                                                                
                                                                           
             
  
            
                                                                           
                                                                             
                                 
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_array_set_fd(xpc_object_t xarray, size_t index, int fd);

   
                                     
  
            
                                      
  
                
                                               
  
               
                                                                               
                                                                                
                                                                           
             
  
                    
                                                                      
                                                                             
                                                                              
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL3
void
xpc_array_set_connection(xpc_object_t xarray, size_t index,
	xpc_connection_t connection);

#pragma mark Array Primitive Getters
   
                               
  
            
                                                                   
  
                
                                     
  
               
                                                                               
                                                                               
                                                          
  
          
                                                                              
                                                       
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
bool
xpc_array_get_bool(xpc_object_t xarray, size_t index);

   
                                
  
            
                                                                       
  
                
                                     
  
               
                                                                               
                                                                               
                                                          
  
          
                                                                             
                                                              
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
int64_t
xpc_array_get_int64(xpc_object_t xarray, size_t index);

   
                                 
  
            
                                                                       
  
                
                                     
  
               
                                                                               
                                                                               
                                                          
  
          
                                                                              
                                                                 
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
uint64_t
xpc_array_get_uint64(xpc_object_t xarray, size_t index);

   
                                 
  
            
                                                                     
  
                
                                     
  
               
                                                                               
                                                                               
                                                          
  
          
                                                                              
                                                              
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
double
xpc_array_get_double(xpc_object_t xarray, size_t index);

   
                               
  
            
                                               
  
                
                                     
  
               
                                                                               
                                                                               
                                                          
  
          
                                                                            
                                                                             
                                                                              
                
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
int64_t
xpc_array_get_date(xpc_object_t xarray, size_t index);

   
                               
  
            
                                                                           
  
                
                                     
  
               
                                                                               
                                                                               
                                                          
  
                
                                                                        
                 
  
          
                                                                        
                                       
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
const void * _Nullable
xpc_array_get_data(xpc_object_t xarray, size_t index,
	size_t * _Nullable length);

   
                                 
  
            
                                                
  
                
                                     
  
               
                                                                               
                                                                               
                                                          
  
          
                                                                           
                                           
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
const char * _Nullable
xpc_array_get_string(xpc_object_t xarray, size_t index);

   
                               
  
            
                                                           
  
                
                                     
  
               
                                                                               
                                                                               
                                                          
  
          
                                                                            
                                                                             
                                                    
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
const uint8_t * _Nullable
xpc_array_get_uuid(xpc_object_t xarray, size_t index);

   
                             
  
            
                                                 
  
                
                                     
  
               
                                                                               
                                                                               
                                                          
  
          
                                                                               
                                                                                
                                        
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
int
xpc_array_dup_fd(xpc_object_t xarray, size_t index);

   
                                        
  
            
                                                      
  
                
                                     
  
               
                                                                               
                                                                               
                                                          
  
          
                                                                          
                                                                                
                                                                                
                                                                        
                                                                              
                                                                       
              
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
xpc_connection_t _Nullable
xpc_array_create_connection(xpc_object_t xarray, size_t index);

   
                                     
  
            
                                                              
  
                
                                            
  
               
                                                                            
                                                 
   
          
                                                                          
                                                                         
                    
  
              
                                                                              
                                                                   
   
__OSX_AVAILABLE_STARTING(__MAC_10_11, __IPHONE_9_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_object_t _Nullable
xpc_array_get_dictionary(xpc_object_t xarray, size_t index);

   
                                
  
            
                                                         
  
                
                                            
  
               
                                                                            
                                                 
   
          
                                                                          
                                                                         
                
  
              
                                                                              
                                                                   
   
__OSX_AVAILABLE_STARTING(__MAC_10_11, __IPHONE_9_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_object_t _Nullable
xpc_array_get_array(xpc_object_t xarray, size_t index);

#pragma mark Dictionary
   
                                    
                                                                    
  
             
                                    
  
               
                                      
  
          
                                                          
   
#ifdef __BLOCKS__
typedef bool (^xpc_dictionary_applier_t)(const char * _Nonnull key,
		xpc_object_t _Nonnull value);
#endif               

   
                                  
  
            
                                                                          
             
  
              
                                                                               
                                                                               
                                          
  
                
                                                                              
                                                                               
                     
  
               
                                                                               
                                                                              
                       
  
                                                                     
                                                                         
                                                                             
                         
  
          
                             
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_dictionary_create(
	const char *XPC_CSTRING _Nonnull const *XPC_COUNTEDBY(count) _Nullable keys,
	const xpc_object_t _Nullable *XPC_COUNTEDBY(count) _Nullable values, size_t count);

   
                                        
  
            
                                                                          
             
  
          
                             
  
       
                        
   
API_AVAILABLE(macos(11.0), ios(14.0), tvos(14.0), watchos(7.0))
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_dictionary_create_empty(void);

   
                                        
   
            
                                                                 
  
                  
                                                    
  
          
                                                                            
                 
  
              
                                                                               
                                                                     
  
                                                                             
                            
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_object_t _Nullable
xpc_dictionary_create_reply(xpc_object_t original);

   
                                     
  
            
                                                                
  
               
                                                    
  
             
                                            
  
               
                                                                           
                                                                          
                                                                              
                                                                      
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_value(xpc_object_t xdict, const char *key,
	xpc_object_t _Nullable value);

   
                                     
  
            
                                           
  
               
                                                 
  
             
                                         
   
          
                                                                              
                                                                            
                  
  
              
                                                                              
                                                                   
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1 XPC_NONNULL2
xpc_object_t _Nullable
xpc_dictionary_get_value(xpc_object_t xdict, const char *key);

   
                                     
  
            
                                                         
  
               
                                                 
  
          
                                                                             
                                                                            
                                                                             
                                       
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
size_t
xpc_dictionary_get_count(xpc_object_t xdict);

   
                                 
  
            
                                                                      
  
               
                                                 
  
                 
                                                                        
              
   
          
                                                                     
                                                                             
  
              
                                                                              
                                                   
   
#ifdef __BLOCKS__
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
bool
xpc_dictionary_apply(xpc_object_t xdict,
		XPC_NOESCAPE xpc_dictionary_applier_t applier);
#endif               

   
                                                 
  
            
                                                                 
  
               
                                                 
  
          
                                                                               
                                                                                
                                                                             
            
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_connection_t _Nullable
xpc_dictionary_get_remote_connection(xpc_object_t xdict);

#pragma mark Dictionary Primitive Setters
   
                                    
  
            
                                                                   
  
               
                                             
  
             
                                                      
  
               
                                                                            
                                                                               
                                           
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_bool(xpc_object_t xdict, const char *key, bool value);

   
                                     
  
            
                                                                       
  
               
                                             
  
             
                                                      
  
               
                                                                               
                                                                               
                                           
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_int64(xpc_object_t xdict, const char *key, int64_t value);

   
                                      
  
            
                                                                       
  
               
                                             
  
             
                                                      
  
               
                                                                                
                                                                               
                                           
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_uint64(xpc_object_t xdict, const char *key, uint64_t value);

   
                                      
  
            
                                                                     
  
               
                                             
  
             
                                                      
  
               
                                                                              
                                                                               
                                           
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_double(xpc_object_t xdict, const char *key, double value);

   
                                    
  
            
                                          
  
               
                                             
  
             
                                            
  
               
                                                                        
                                                                             
                                                                             
                                                                             
                                                     
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_date(xpc_object_t xdict, const char *key, int64_t value);

   
                                    
  
            
                                              
  
               
                                             
  
             
                                                      
  
               
                                                                                 
                                                                             
                                                     
  
                
                          
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_data(xpc_object_t xdict, const char *key,
	const void *XPC_SIZEDBY(length) _Nullable bytes, size_t length);

   
                                      
  
            
                                              
  
               
                                             
  
             
                                                      
  
                
                                                                     
                                                                             
                                      
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2 XPC_NONNULL3
void
xpc_dictionary_set_string(xpc_object_t xdict, const char *key,
	const char *string);

   
                                    
  
            
                                                      
  
               
                                             
  
             
                                                      
  
              
                                                                              
                                                                               
                                           
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2 XPC_NONNULL3
void
xpc_dictionary_set_uuid(xpc_object_t xdict, const char *key,
	const uuid_t XPC_NONNULL_ARRAY uuid);

   
                                  
  
            
                                               
  
               
                                             
  
             
                                                      
  
            
                                                                           
                                                                        
                                           
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_fd(xpc_object_t xdict, const char *key, int fd);

   
                                          
  
            
                                          
  
               
                                             
  
             
                                                      
  
                    
                                                                      
                                                                        
                                                                             
                  
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2 XPC_NONNULL3
void
xpc_dictionary_set_connection(xpc_object_t xdict, const char *key,
	xpc_connection_t connection);

   
                                         
  
            
                                          
  
               
                                             
  
             
                                                      
  
           
                                                                
                                                                        
                                                
  
              
                                                                            
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_mach_send(xpc_object_t xdict, const char *key,
	mach_port_t p);

#pragma mark Dictionary Primitive Getters
   
                                    
  
            
                                                                       
  
               
                                                 
  
             
                                         
  
          
                                                                             
                                                                           
                               
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
bool
xpc_dictionary_get_bool(xpc_object_t xdict, const char *key);

   
                                     
  
            
                                                                           
  
               
                                                 
  
             
                                         
  
          
                                                                            
                                                                              
                               
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
int64_t
xpc_dictionary_get_int64(xpc_object_t xdict, const char *key);

   
                                      
  
            
                                                                           
  
               
                                                 
  
             
                                         
  
          
                                                                             
                                                                              
                                  
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
uint64_t
xpc_dictionary_get_uint64(xpc_object_t xdict, const char *key);

   
                                      
  
            
                                                                         
  
               
                                                 
  
             
                                         
  
          
                                                                             
                                                                              
                               
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
double
xpc_dictionary_get_double(xpc_object_t xdict, const char *key);

   
                                    
  
            
                                                
  
               
                                                 
  
             
                                         
  
          
                                                                           
                                                                             
                                                                               
                                                            
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
int64_t
xpc_dictionary_get_date(xpc_object_t xdict, const char *key);

   
                                    
  
            
                                                    
  
               
                                                 
  
             
                                         
  
                
                                                                               
                                                               
  
          
                                                                           
                                                                              
       
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
const void * _Nullable
xpc_dictionary_get_data(xpc_object_t xdict, const char *key,
	size_t * _Nullable length);

   
                                      
  
            
                                                    
  
               
                                                 
  
             
                                         
  
          
                                                                           
                                                                        
                 
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
const char * _Nullable
xpc_dictionary_get_string(xpc_object_t xdict, const char *key);

   
                                    
  
            
                                                
  
               
                                                 
  
             
                                         
  
          
                                                                              
                                                                                
                                     
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1 XPC_NONNULL2
const uint8_t * _Nullable
xpc_dictionary_get_uuid(xpc_object_t xdict, const char *key);

   
                                  
  
            
                                                        
  
               
                                                 
  
             
                                         
  
          
                                                                              
                                                                       
                                                                               
                 
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
int
xpc_dictionary_dup_fd(xpc_object_t xdict, const char *key);

   
                                             
  
            
                                                   
  
               
                                                 
  
             
                                         
  
          
                                                                         
                                                                                
                                                                               
                                                                            
                                                                         
                                                                         
                                                              
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_connection_t _Nullable
xpc_dictionary_create_connection(xpc_object_t xdict, const char *key);

   
                                          
  
            
                                                      
  
               
                                                 
  
             
                                         
   
          
                                                                              
                                                                          
                                                                              
  
              
                                                                              
                                                                   
   
__OSX_AVAILABLE_STARTING(__MAC_10_11, __IPHONE_9_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_object_t _Nullable
xpc_dictionary_get_dictionary(xpc_object_t xdict, const char *key);

   
                                     
  
            
                                                 
  
               
                                                 
  
             
                                         
   
          
                                                                              
                                                                          
                                                                          
  
              
                                                                              
                                                                   
   
__OSX_AVAILABLE_STARTING(__MAC_10_11, __IPHONE_9_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_object_t _Nullable
xpc_dictionary_get_array(xpc_object_t xdict, const char *key);

   
                                          
  
            
                                         
  
               
                                                 
  
             
                                         
  
          
                                                                           
                                                                              
                                                                                  
         
  
              
                                                                      
                            
   
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1 XPC_NONNULL2
mach_port_t
xpc_dictionary_copy_mach_send(xpc_object_t xdict, const char *key);

#pragma mark Runtime
   
                     
                                                                              
                                                                               
                                                                               
                                                                            
                                                       
  
                 
                                                                               
                                                                            
                                                         
                                                                             
                                                                            
                                                                               
                                                                   
   
API_AVAILABLE(macos(10.7), macCatalyst(5.0))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_NORETURN XPC_NONNULL1
void
xpc_main(xpc_connection_handler_t handler);

#pragma mark Transactions
   
                                  
                                                                            
                                     
   
              
                                                                           
                                          
  
                                                                           
                                                                                
                                                                                
                                                                               
                       
  
                                                                                
                                                                       
                                                                                         
                                                                         
                                                                              
                                                                          
                                         
  
                                                                              
                                                                  
                                                                           
                                                                         
                                                                        
              
   
API_AVAILABLE(macos(10.7))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_TRANSACTION_DEPRECATED
XPC_EXPORT
void
xpc_transaction_begin(void);

   
                                
                                                        
   
              
                                                                        
                                                
  
                                                                               
                                      
   
API_AVAILABLE(macos(10.7))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_TRANSACTION_DEPRECATED
XPC_EXPORT
void
xpc_transaction_end(void);

#pragma mark XPC Event Stream
   
                                         
                                                                      
  
                
                                                                       
  
                 
                                                                         
                                                                             
                                                                                
   
                 
                                                                            
                                                                              
                                                                                
                                                                               
                   
  
              
                                                                           
                      
  
                                                                     
                                                                         
                                                             
   
#if __BLOCKS__
API_AVAILABLE(macos(10.7))
API_UNAVAILABLE(ios, tvos, watchos)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL3
void
xpc_set_event_stream_handler(const char *stream,
	dispatch_queue_t _Nullable targetq, XPC_SWIFT_SENDABLE xpc_handler_t handler);
#endif               

__END_DECLS
XPC_ASSUME_NONNULL_END

#endif              
