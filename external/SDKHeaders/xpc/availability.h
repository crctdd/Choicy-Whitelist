#ifndef __XPC_AVAILABILITY_H__
#define __XPC_AVAILABILITY_H__

#include <Availability.h>
#include <sys/cdefs.h>

__BEGIN_DECLS

                                                                               
                                                                               
                              
#ifndef __MAC_10_16
#define __MAC_10_16 101600
#endif               

#ifndef __MAC_10_15
#define __MAC_10_15 101500
#define __AVAILABILITY_INTERNAL__MAC_10_15 \
__attribute__((availability(macosx, introduced=10.15)))
#endif               

#ifndef __MAC_10_14
#define __MAC_10_14 101400
#define __AVAILABILITY_INTERNAL__MAC_10_14 \
__attribute__((availability(macosx, introduced=10.14)))
#endif               

#ifndef __MAC_10_13
#define __MAC_10_13 101300
#define __AVAILABILITY_INTERNAL__MAC_10_13 \
	__attribute__((availability(macosx, introduced=10.13)))
#endif               

#ifndef __MAC_10_12
#define __MAC_10_12 101200
#define __AVAILABILITY_INTERNAL__MAC_10_12 \
	__attribute__((availability(macosx, introduced=10.12)))
#endif               

#ifndef __MAC_10_11
#define __MAC_10_11 101100
#define __AVAILABILITY_INTERNAL__MAC_10_11 \
	__attribute__((availability(macosx, introduced=10.11)))
#endif               

#ifndef __MAC_12_0
#define __MAC_12_0 120000
#define __AVAILABILITY_INTERNAL__MAC_12_0 \
	__attribute__((availability(macosx, introduced=12.0)))
#endif              

#ifndef __MAC_13_3
#define __MAC_13_3 130300
#endif              

#ifndef __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_2_DEP__MAC_10_11
#endif                                                    

#ifndef __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_3_DEP__MAC_10_11
#endif                                                    

#ifndef __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_4_DEP__MAC_10_11
#endif                                                    

#ifndef __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_5_DEP__MAC_10_11
#endif                                                    

#ifndef __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_11
#endif                                                    

#ifndef __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_7_DEP__MAC_10_11
#endif                                                    

#ifndef __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_8_DEP__MAC_10_11
#endif                                                    

#ifndef __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_9_DEP__MAC_10_11
#endif                                                    

#ifndef __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_10_DEP__MAC_10_11
#endif                                                     

#ifndef __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11
#define __AVAILABILITY_INTERNAL__MAC_10_11_DEP__MAC_10_11
#endif                                                     

#ifndef __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_13
#define __AVAILABILITY_INTERNAL__MAC_10_6_DEP__MAC_10_13
#endif                                                    

#if __has_include(<simulator_host.h>)
__END_DECLS
#include <simulator_host.h>
__BEGIN_DECLS
#else                                     
#ifndef IPHONE_SIMULATOR_HOST_MIN_VERSION_REQUIRED
#define IPHONE_SIMULATOR_HOST_MIN_VERSION_REQUIRED 999999
#endif                                              
#endif                                     

#ifndef __WATCHOS_UNAVAILABLE
#define __WATCHOS_UNAVAILABLE
#endif

#ifndef __TVOS_UNAVAILABLE
#define __TVOS_UNAVAILABLE
#endif

                                                                             
#ifndef __OSX_AVAILABLE
#define __OSX_AVAILABLE(...)
#endif

#ifndef __IOS_AVAILABLE
#define __IOS_AVAILABLE(...)
#endif

#ifndef __TVOS_AVAILABLE
#define __TVOS_AVAILABLE(...)
#endif

#ifndef __WATCHOS_AVAILABLE
#define __WATCHOS_AVAILABLE(...)
#endif

#ifndef __API_AVAILABLE
#define __API_AVAILABLE(...)
#endif

__END_DECLS

#endif                          
