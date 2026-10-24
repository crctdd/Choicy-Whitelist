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

#import "CHPDaemonListController.h"
#import "CHPPreferences.h"
#import "CHWLListSupport.h"

#import "../Shared.h"

#import "CHPDaemonInfo.h"
#import "CHPDaemonList.h"
#import "CHPProcessConfigurationListController.h"
#import "CHPApplicationListSubcontrollerController.h"

@interface PSListController()
- (id)controllerForSpecifier:(PSSpecifier *)specifier;
@end

@implementation CHPDaemonListController

- (void)viewDidLoad
{
	[self applySearchControllerHideWhileScrolling:NO];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(chwlMatchesChanged:) name:CHWLMatchesChanged object:nil];
	[[CHPDaemonList sharedInstance] addObserver:self];

	if (![CHPDaemonList sharedInstance].loaded) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
			[[CHPDaemonList sharedInstance] updateDaemonListIfNeeded];
		});
	}

	[super viewDidLoad];
}

- (NSString *)topTitle
{
	return localize(@"DAEMONS");
}

- (NSString *)plistName
{
	return nil;
}

- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
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
    if (CHWLListStateChanged(self)) [self reloadSpecifiers];
}
- (NSMutableArray *)specifiers
{
    if (!_specifiers) {
        _specifiers = [NSMutableArray new];
        if (![CHPDaemonList sharedInstance].loaded) {
            PSSpecifier *loading = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil
                cell:[PSTableCell cellTypeFromString:@"PSSpinnerCell"] edit:nil];
            [_specifiers addObject:loading];
            return _specifiers;
        }
        NSMutableArray *rows = [NSMutableArray new];
        for (CHPDaemonInfo *info in [CHPDaemonList sharedInstance].daemonList) {
            PSSpecifier *row = [CHPListController createSpecifierForExecutable:info.executablePath named:info.executableName];
            [row setProperty:info.executablePath forKey:@"executablePath"];
            [row setProperty:@YES forKey:@"chwlFrameworkMatching"];
            [row setProperty:@NO forKey:@"chwlPrivilegeEligible"];
            [row setProperty:@(info.thirdPartyProcess) forKey:@"chwlThirdPartyProcess"];
            NSString *displayID = info.bundleIdentifier ?: info.plistIdentifier;
            if (displayID) [row setProperty:displayID forKey:@"processIdentifier"];
            if (info.bundleIdentifier) [row setProperty:info.bundleIdentifier forKey:@"targetBundleIdentifier"];
            NSString *identifier = CHWLIdentifier(row) ?: displayID ?: info.executableName;
            if (_searchKey.length && ![info.executableName localizedStandardContainsString:_searchKey] &&
                ![identifier localizedStandardContainsString:_searchKey]) continue;
            [rows addObject:row];
        }
        [_specifiers addObjectsFromArray:CHWLGroupRows(rows, @"DAEMONS")];
        CHWLRememberListState(self);
    }
    return _specifiers;
}

- (id)previewStringForSpecifier:(PSSpecifier *)specifier
{
	return [CHPListController previewStringForSpecifier:specifier];
}

- (void)reloadValueOfSelectedSpecifier
{
	UITableView *tableView = [self valueForKey:@"_table"];
	for (NSIndexPath *selectedIndexPath in tableView.indexPathsForSelectedRows) {
		PSSpecifier *specifier = [self specifierAtIndex:[self indexForIndexPath:selectedIndexPath]];
		[self reloadSpecifier:specifier];
	}
}

- (void)daemonListDidUpdate:(CHPDaemonList *)list
{
    if (self.isViewLoaded && self.view.window && self.navigationController.topViewController == self) [self reloadSpecifiers];
    else _specifiers = nil;
}

- (id)controllerForSpecifier:(PSSpecifier *)specifier
{
	if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_11_0) {
		[UIView performWithoutAnimation:^ {
			_searchController.active = NO;
		}];
	}

	return [super controllerForSpecifier:specifier];
}

@end
