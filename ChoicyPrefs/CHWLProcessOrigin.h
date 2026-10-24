#import <Foundation/Foundation.h>

enum { CHWLProcessOriginVersion = 1 };
BOOL CHWLPathIsInsideDirectory(NSString *path, NSString *directory);
NSString *CHWLOwningApplicationPath(NSString *executablePath);
BOOL CHWLIsThirdPartyProcess(NSString *executablePath, NSString *launchDaemonPath,
    NSString *jailbreakRoot, NSString *applicationIdentifier);
BOOL CHWLProcessOriginsAreCurrent(NSDictionary *cache);
