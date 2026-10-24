#ifndef __XPC_PEER_REQ_H__
#define __XPC_PEER_REQ_H__

#ifndef __XPC_INDIRECT__
#error "Please #include <xpc/xpc.h> instead of this file directly."
                 
#include <xpc/base.h>
#endif                    

XPC_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS

XPC_SWIFT_NOEXPORT
   
                                  
  
            
                                                                        
                        
  
              
                                                                           
                                                                           
                                                                               
                                                                       
  
                                                                        
                                                                            
                
   
OS_OBJECT_DECL_SENDABLE_CLASS(xpc_peer_requirement);

#pragma mark Constructors

   
                                                           
                                                                   
  
                     
                                                                               
                                      
  
                   
                                                                               
                                                                               
  
          
                                                                              
                                                                           
           
  
              
                                                                            
           
   
API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0))

XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED
xpc_peer_requirement_t _Nullable
xpc_peer_requirement_create_entitlement_exists(const char *entitlement,
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

   
                                                                  
                                                                             
  
                     
                                                                               
                                      
  
               
                                                                                
                                                                          
                                                           
  
                   
                                                                               
                                                                               
  
          
                                                                              
                                                                           
           
  
              
                                                                            
           
   
API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0))

XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED
xpc_peer_requirement_t _Nullable
xpc_peer_requirement_create_entitlement_matches_value(const char *entitlement,
		xpc_object_t value, 
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

   
                                                      
                                                                              
                                                       
  
                            
                                                                               
                                                             
  
                   
                                                                               
                                                                               
  
          
                                                                              
                                                                           
           
  
              
                                                                         
           
  
                                                                             
                                                                              
                                                                                
        
   
API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0))

XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED
xpc_peer_requirement_t _Nullable
xpc_peer_requirement_create_team_identity(
		const char * _Nullable signing_identifier,
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

   
                                                          
                                                                            
                   
  
                            
                                                                             
                                                                              
                                                                         
            
  
                   
                                                                               
                                                                               
  
          
                                                                              
                                                                           
           
  
              
                                                                         
           
   
API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0))

XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED
xpc_peer_requirement_t _Nullable
xpc_peer_requirement_create_platform_identity(
		const char * _Nullable signing_identifier,
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

   
                                             
                                                                                    
  
              
                                                                                
                                                                       
  
                   
                                                                               
                                                                               
  
          
                                                                              
                                                                           
           
  
              
                                                                              
              
  
                                                                               
                          
                                                                                                         
                                                 
  
                                                                              
                                                                                
                                      
       
                                                       
                                                                      
                                                              
  
                                                     
                                                 
  
                                                                             
      
   
API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0))

XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED
xpc_peer_requirement_t _Nullable
xpc_peer_requirement_create_lwcr(xpc_object_t lwcr, 
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

#pragma mark Matching Peer Requirement on Received Messages

   
                                                        
                                                                            
  
                          
                                     
  
                 
                                        
   
                   
                                                                               
                                                                               
  
          
                                                                                
                                                                    
   
API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0))

XPC_EXPORT XPC_SWIFT_NOEXPORT
bool
xpc_peer_requirement_match_received_message(xpc_peer_requirement_t peer_requirement,
		xpc_object_t message, 
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

__END_DECLS
XPC_ASSUME_NONNULL_END

#endif
