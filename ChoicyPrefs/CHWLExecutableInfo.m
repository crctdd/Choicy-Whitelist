#import "CHWLExecutableInfo.h"
#import <CoreFoundation/CoreFoundation.h>

static NSString *CHWLIdentifierFromURL(NSURL *url)
{
    NSDictionary *info = CFBridgingRelease(CFBundleCopyInfoDictionaryForURL((__bridge CFURLRef)url));
    id identifier = [info isKindOfClass:NSDictionary.class] ? info[@"CFBundleIdentifier"] : nil;
    if (![identifier isKindOfClass:NSString.class] || ![identifier length] || [identifier length] > 1024 ||
        [identifier rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound) return nil;
    return identifier;
}

NSString *CHWLBundleIdentifierForExecutable(NSString *path)
{
    if (![path isAbsolutePath]) return nil;
    NSString *directory = path.stringByDeletingLastPathComponent;
    if ([@[@"app", @"appex", @"xpc", @"bundle"] containsObject:directory.pathExtension]) {
        NSString *identifier = CHWLIdentifierFromURL([NSURL fileURLWithPath:directory isDirectory:YES]);
        if (identifier) return identifier;
    }
                                                                                     
    return CHWLIdentifierFromURL([NSURL fileURLWithPath:path isDirectory:NO]);
}
