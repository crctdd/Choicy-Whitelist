// Copyright (c) 2019-2021 Lars Fröder

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#import "CHPApplicationPlugInsListController.h"
#import "CoreServices.h"
#import <MobileCoreServices/LSApplicationProxy.h>
#import <MobileCoreServices/LSPlugInKitProxy.h>
#import "CHPProcessConfigurationListController.h"
#import "../Shared.h"
#import "CHPPreferences.h"
#import "CHPApplicationListSubcontrollerController.h"
#import "CHPListController.h"

#import <MobileCoreServices/LSApplicationWorkspace.h>
#import "CHWLListSupport.h"
#import "CHWLComponentSupport.h"
#import "CHPDaemonList.h"
#import "CHWLExtensionRegistry.h"

@interface CHPApplicationPlugInsListController ()
@property (nonatomic) BOOL loadingComponents;
@property (nonatomic) NSUInteger componentRequest;
@end

@implementation CHPApplicationPlugInsListController
- (NSString *)topTitle { return localize(@"APP_PLUGINS"); }
- (void)viewDidLoad
{
    [self applySearchControllerHideWhileScrolling:NO];
    [super viewDidLoad];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationExtensionsChanged:)
        name:CHWLApplicationExtensionsChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(chwlMatchesChanged:) name:CHWLMatchesChanged object:nil];
}
- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}
- (void)chwlMatchesChanged:(NSNotification *)note
{
    if (self.isViewLoaded && self.view.window && self.navigationController.topViewController == self && CHWLListStateChanged(self)) [self reloadSpecifiers];
}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    extern void choicy_reloadPreferences(void);
    choicy_reloadPreferences();
    CHWLRefreshMatches();
    if (![self.specifier propertyForKey:@"applicationIdentifier"]) dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [CHPDaemonList.sharedInstance prepareApplicationExtensionsIfNeeded];
    });
    if (CHWLListStateChanged(self)) [self reloadSpecifiers];
}
- (void)applicationExtensionsChanged:(NSNotification *)note
{
    (void)note;
    if ([self.specifier propertyForKey:@"applicationIdentifier"]) return;
    NSArray *snapshot = CHPDaemonList.sharedInstance.applicationExtensions;
    if (!snapshot || [_appPlugIns isEqual:snapshot]) return;
    self.componentRequest++;
    self.loadingComponents = NO;
    _appPlugIns = snapshot;
    _specifiers = nil;
    if (self.isViewLoaded && self.view.window && self.navigationController.topViewController == self) [self reloadSpecifiers];
}
- (void)loadPlugIns
{
    if (self.loadingComponents || _appPlugIns) return;
    NSString *appID = [self.specifier propertyForKey:@"applicationIdentifier"];
    NSArray *cached = appID ? nil : CHPDaemonList.sharedInstance.applicationExtensions;
    if (cached) { _appPlugIns = cached; return; }
    self.loadingComponents = YES;
    NSUInteger request = ++self.componentRequest;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSArray *snapshot;
        if (appID) snapshot = CHWLRegisteredExtensionRecords(appID);
        else {
            [CHPDaemonList.sharedInstance prepareApplicationExtensionsIfNeeded];
            snapshot = CHPDaemonList.sharedInstance.applicationExtensions;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) controller = weakSelf;
            if (!controller || controller.componentRequest != request) return;
            controller->_appPlugIns = snapshot ?: @[];
            controller.loadingComponents = NO;
            controller->_specifiers = nil;
            if (controller.isViewLoaded && controller.view.window && controller.navigationController.topViewController == controller) [controller reloadSpecifiers];
        });
    });
}
- (NSMutableArray *)specifiers
{
    if (!_specifiers) {
        if (!_appPlugIns) [self loadPlugIns];
        if (!_appPlugIns) {
            _specifiers = [NSMutableArray arrayWithObject:[PSSpecifier preferenceSpecifierNamed:localize(@"LOADING_APP_EXTENSIONS")
                target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil]];
            return _specifiers;
        }
        NSMutableArray *rows = [NSMutableArray new];
        for (NSDictionary *plugin in _appPlugIns) {
            NSString *path = plugin[@"executablePath"];
            NSString *identifier = plugin[@"bundleIdentifier"];
            NSString *name = plugin[@"name"];
            if (_searchKey.length && ![name localizedStandardContainsString:_searchKey] &&
                ![identifier localizedStandardContainsString:_searchKey]) continue;
            PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:name target:self set:nil get:nil
                detail:CHPProcessConfigurationListController.class cell:PSLinkCell edit:nil];
            [row setProperty:identifier forKey:@"pluginIdentifier"];
            [row setProperty:@NO forKey:@"chwlPrivilegeEligible"];
            if (path) [row setProperty:path forKey:@"executablePath"];
            [row setProperty:@YES forKey:@"chwlFrameworkMatching"];
            [rows addObject:row];
        }
        _specifiers = CHWLGroupRows(rows, @"APP_PLUGINS");
        CHWLRememberListState(self);
    }
    return _specifiers;
}
@end
