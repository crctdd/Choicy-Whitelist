#import "CHWLProcessOrigin.h"

static NSString *CHWLOriginPath(NSString *path)
{
    if (![path isKindOfClass:NSString.class] || !path.isAbsolutePath) return nil;
    path = path.stringByStandardizingPath;
    if ([path hasPrefix:@"/private/var/"]) path = [path substringFromIndex:8];
    return path;
}

BOOL CHWLPathIsInsideDirectory(NSString *path, NSString *directory)
{
    path = CHWLOriginPath(path);
    directory = CHWLOriginPath(directory);
    if (!path.length || !directory.length || [directory isEqualToString:@"/"]) return NO;
    return [path isEqualToString:directory] || [path hasPrefix:[directory stringByAppendingString:@"/"]];
}

NSString *CHWLOwningApplicationPath(NSString *executablePath)
{
    NSString *path = CHWLOriginPath(executablePath).stringByDeletingLastPathComponent;
    while (path.length > 1) {
        if ([path.pathExtension isEqualToString:@"app"]) return path;
        path = path.stringByDeletingLastPathComponent;
    }
    return nil;
}

BOOL CHWLIsThirdPartyProcess(NSString *executablePath, NSString *launchDaemonPath,
    NSString *jailbreakRoot, NSString *applicationIdentifier)
{
    NSString *path = CHWLOriginPath(executablePath);
    if (!path.length) return NO;
    if (CHWLPathIsInsideDirectory(path, jailbreakRoot)) return YES;
    for (NSString *directory in @[@"/System", @"/usr", @"/bin", @"/sbin",
        @"/private/preboot/Cryptexes/OS/System"]) {
        if (CHWLPathIsInsideDirectory(path, directory)) return NO;
    }
    NSString *application = CHWLOwningApplicationPath(path);
    if (application.length && CHWLPathIsInsideDirectory(application, @"/var/containers/Bundle/Application")) return YES;
    if (application.length && CHWLPathIsInsideDirectory(application, @"/Applications") &&
        [applicationIdentifier isKindOfClass:NSString.class] && applicationIdentifier.length)
        return ![applicationIdentifier hasPrefix:@"com.apple."];
    return CHWLPathIsInsideDirectory(launchDaemonPath, @"/Library/LaunchDaemons") ||
        CHWLPathIsInsideDirectory(launchDaemonPath, jailbreakRoot);
}

BOOL CHWLProcessOriginsAreCurrent(NSDictionary *cache)
{
    if (![cache isKindOfClass:NSDictionary.class] ||
        ![cache[@"processOriginVersion"] isEqual:@(CHWLProcessOriginVersion)]) return NO;
    id records = cache[@"processes"];
    if (![records isKindOfClass:NSArray.class] || ![records count]) return NO;
    for (id record in records) {
        if (![record isKindOfClass:NSDictionary.class]) return NO;
        id flag = record[@"thirdPartyProcess"];
        if (![flag isKindOfClass:NSNumber.class] || (![flag isEqual:@YES] && ![flag isEqual:@NO])) return NO;
    }
    return YES;
}
