#import "CHWLExtensionRegistry.h"
#import "CoreServices.h"
#import "CHPProcessConfigurationListController.h"
#import "CHWLComponentSupport.h"
#import <MobileCoreServices/LSApplicationWorkspace.h>
#import <MobileCoreServices/LSApplicationProxy.h>
#import <MobileCoreServices/LSPlugInKitProxy.h>

NSArray<NSDictionary *> *CHWLRegisteredExtensionRecords(NSString *applicationIdentifier)
{
    LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
    LSApplicationProxy *selected = applicationIdentifier ?
        [LSApplicationProxy applicationProxyForIdentifier:applicationIdentifier] : nil;
    NSArray *apps = applicationIdentifier ? (selected ? @[selected] : @[]) : [workspace allInstalledApplications];
    if (!apps || (!applicationIdentifier && !apps.count)) return nil;
    NSMutableArray *proxies = [NSMutableArray new];
    for (LSApplicationProxy *app in apps) {
        [proxies addObjectsFromArray:app.plugInKitPlugins ?: @[]];
        [proxies addObjectsFromArray:app.VPNPlugins ?: @[]];
    }
    if (!applicationIdentifier && [workspace respondsToSelector:@selector(pluginsWithIdentifiers:protocols:version:)]) {
        [proxies addObjectsFromArray:[workspace pluginsWithIdentifiers:@[] protocols:@[] version:nil] ?: @[]];
    }
    NSMutableArray *records = [NSMutableArray new];
    for (LSPlugInKitProxy *plugin in proxies) {
        NSString *path = [CHPProcessConfigurationListController executablePathForBundleProxy:plugin];
        NSString *identifier = plugin.bundleIdentifier;
        if (!identifier.length || !path.isAbsolutePath) continue;
        [records addObject:@{@"bundleIdentifier": identifier, @"executablePath": path,
            @"name": plugin.localizedName.length ? plugin.localizedName : path.lastPathComponent,
            @"kind": [path.stringByDeletingLastPathComponent.pathExtension isEqual:@"appex"] ? @"appex" : @"registered"}];
    }
    return CHWLMergeExtensionRecords(records, @[]);
}
