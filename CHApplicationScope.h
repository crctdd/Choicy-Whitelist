#import <Foundation/Foundation.h>

static inline BOOL CHApplicationHasHiddenTags(id tags)
{
    if (![tags isKindOfClass:NSArray.class]) return NO;
    for (id tag in tags) {
        if ([tag isKindOfClass:NSString.class] && [tag containsString:@"hidden"]) return YES;
    }
    return NO;
}

 
static inline BOOL CHVisibleApplicationMetadataAllowsPrivilege(NSString *identifier, NSString *bundlePath,
    id infoTags, id proxyTags, id recordTags, BOOL launchProhibited)
{
    return identifier.length && [bundlePath.pathExtension isEqualToString:@"app"] &&
        ![identifier isEqualToString:@"com.apple.springboard"] &&
        [identifier rangeOfString:@"com.apple.webapp" options:NSCaseInsensitiveSearch].location == NSNotFound &&
        !launchProhibited && !CHApplicationHasHiddenTags(infoTags) &&
        !CHApplicationHasHiddenTags(proxyTags) && !CHApplicationHasHiddenTags(recordTags);
}
