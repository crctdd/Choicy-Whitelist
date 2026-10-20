#import "CHWLListSupport.h"
#import "CHWLData.h"
#import "CHWLFrameworkMatches.h"
#import "CHPPreferences.h"
#import "CHPProcessConfigurationListController.h"
#import "CHPTweakList.h"
#import "CHPTweakInfo.h"
#import "CHPPackageInfo.h"
#import "CHPDaemonList.h"
#import "CHPDaemonInfo.h"
#import "../Shared.h"
#import <MobileCoreServices/LSPlugInKitProxy.h>
#import <objc/runtime.h>

NSString *const CHWLMatchesChanged = @"CHWLMatchesChanged";
static char CHWLListStateKey;

void CHWLRefreshMatches(void)
{

    static BOOL pending;
    static CFAbsoluteTime lastCheck;
    if (pending || CFAbsoluteTimeGetCurrent() - lastCheck < 2) return;
    pending = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        BOOL changed = [[CHPTweakList sharedInstance] refreshTweakListIfNeeded];
        dispatch_async(dispatch_get_main_queue(), ^{
            pending = NO;
            lastCheck = CFAbsoluteTimeGetCurrent();
            if (changed) [NSNotificationCenter.defaultCenter postNotificationName:CHWLMatchesChanged object:nil];
        });
    });
}

static NSDictionary *CHWLCurrentListState(void)
{
    return @{@"preferences": preferences ?: @{}, @"targets": @([CHPTweakList sharedInstance].targetGeneration),
        @"frameworks": @(CHWLFrameworkGeneration())};
}

void CHWLRememberListState(id controller)
{
    objc_setAssociatedObject(controller, &CHWLListStateKey, CHWLCurrentListState(), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

BOOL CHWLListStateChanged(id controller)
{
    return ![objc_getAssociatedObject(controller, &CHWLListStateKey) isEqual:CHWLCurrentListState()];
}

NSArray *CHWLMatchesForSpecifier(PSSpecifier *row)
{
    NSString *identifier = CHWLIdentifier(row) ?: [row propertyForKey:@"targetBundleIdentifier"];
    NSString *path = CHWLExecutable(row);
    NSSet *frameworks = CHWLUsesFrameworkMatching(row) ? CHWLCachedFrameworkIdentifiers(path) : nil;
    return [[CHPTweakList sharedInstance] tweaksForBundleIdentifier:identifier executableName:path.lastPathComponent frameworkIdentifiers:frameworks];
}

BOOL CHWLUsesFrameworkMatching(PSSpecifier *row)
{
    return [[row propertyForKey:@"chwlFrameworkMatching"] boolValue] ||
        (!CHWLIdentifier(row).length && CHWLExecutable(row).length);
}
void CHWLRequestFrameworkMatchesForSpecifier(PSSpecifier *row)
{
    if (CHWLUsesFrameworkMatching(row)) CHWLRequestFrameworkIdentifiers(CHWLExecutable(row));
}

NSString *CHWLIdentifier(PSSpecifier *row)
{
    return [row propertyForKey:@"applicationIdentifier"] ?: [row propertyForKey:@"pluginIdentifier"];
}

BOOL CHWLPrivilegeEligibleForSpecifier(PSSpecifier *row)
{
    id scope = [row propertyForKey:@"chwlPrivilegeEligible"];
    if ([scope isKindOfClass:NSNumber.class]) return [scope boolValue];
    NSString *identifier = [row propertyForKey:@"applicationIdentifier"];
    BOOL eligible = identifier.length && CHApplicationSupportsPrivilege(identifier);
    [row setProperty:@(eligible) forKey:@"chwlPrivilegeEligible"];
    return eligible;
}

NSString *CHWLExecutable(PSSpecifier *row)
{
    NSString *path = [row propertyForKey:@"executablePath"];
    if (path.length) return path;
    NSString *app = [row propertyForKey:@"applicationIdentifier"];
    if (app.length) path = CHExecutablePathForApplication(app);
    else {
        NSString *plugin = [row propertyForKey:@"pluginIdentifier"];
        if (plugin.length) path = [CHPProcessConfigurationListController executablePathForBundleProxy:
            [LSPlugInKitProxy pluginKitProxyForIdentifier:plugin]];
    }
    if (path.length) [row setProperty:path forKey:@"executablePath"];
    return path;
}

void CHWLDecorateRow(PSSpecifier *row)
{
    NSString *identifier = CHWLIdentifier(row);
    NSString *path = CHWLExecutable(row);
    NSString *subtitle = identifier ?: [row propertyForKey:@"processIdentifier"] ?: path.lastPathComponent ?: @"";
    BOOL enabled = CHInjectionEnabled(preferences, identifier, path);
    BOOL privilegeEligible = CHWLPrivilegeEligibleForSpecifier(row);

    BOOL matched = [[CHPTweakList sharedInstance] explicitTweaksForBundleIdentifier:
        (identifier ?: [row propertyForKey:@"targetBundleIdentifier"]) executableName:path.lastPathComponent].count > 0;
    NSDictionary *settings = identifier.length ? processPreferencesForApplication(preferences, identifier) :
        processPreferencesForDaemon(preferences, path.lastPathComponent);
    [row setProperty:NSClassFromString(@"CHWLProcessCell") forKey:@"cellClass"];
    [row setProperty:subtitle forKey:@"chwlIdentifier"];
    [row setProperty:@(enabled) forKey:@"chwlInjectionEnabled"];
    [row setProperty:@(matched) forKey:@"chwlMatched"];
    [row setProperty:@(CHWLPrivilegesDisabled(enabled, privilegeEligible, settings)) forKey:@"chwlPrivilegesDisabled"];
    [row setProperty:CHWLConfigurationSummary(enabled, privilegeEligible, settings) forKey:@"chwlConfigurationSummary"];
    [row setProperty:@(!enabled && matched ? 72 : 56) forKey:@"height"];
}

NSMutableArray *CHWLGroupRows(NSArray<PSSpecifier *> *rows, NSString *name)
{
    NSMutableArray *records = [NSMutableArray new];
    for (PSSpecifier *row in rows) {
        CHWLDecorateRow(row);
        [records addObject:@{@"name": row.name ?: @"", @"identifier": [row propertyForKey:@"chwlIdentifier"] ?: @"",
            @"enabled": [row propertyForKey:@"chwlInjectionEnabled"], @"matched": [row propertyForKey:@"chwlMatched"],
            @"privilegesDisabled": [row propertyForKey:@"chwlPrivilegesDisabled"],
            @"row": row}];
    }
    NSMutableArray *result = [NSMutableArray new];
    NSInteger previous = -1;
    for (NSDictionary *record in CHWLSortedRows(records)) {
        NSInteger section = [record[@"enabled"] boolValue] ? 0 : 1;
        if (section != previous) {
            NSString *status = [name isEqualToString:@"隐藏应用"] ?
                (section == 0 ? @"已开启" : @"未开启") : (section == 0 ? @"已启用" : @"未启用");
            [result addObject:[PSSpecifier groupSpecifierWithName:[NSString stringWithFormat:@"%@ · %@", name,
                status]]];
            previous = section;
        }
        [result addObject:record[@"row"]];
    }
    return result;
}
