#import "SpringBoard.h"

extern NSDictionary *preferences;

void choicy_reloadPreferences(void);
NSDictionary *choicy_applyEnvironmentChanges(NSDictionary *originalEnvironment, NSString *bundleIdentifier);
void choicy_applyEnvironmentChangesToLaunchContext(RBSLaunchContext *launchContext);
void choicy_applyEnvironmentChangesToExecutionContext(FBProcessExecutionContext *executionContext, NSString *bundleIdentifier);
