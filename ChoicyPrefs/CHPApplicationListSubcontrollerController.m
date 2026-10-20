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

#import "CHPApplicationListSubcontrollerController.h"
#import "../Shared.h"
#import "CHPPreferences.h"
#import "CHPListController.h"
#import "CHWLListSupport.h"
#import "CHWLData.h"
#import <AltList/ATLApplicationSection.h>
#import <objc/runtime.h>

static char CHWLGroupedKey;
@implementation CHPApplicationListSubcontrollerController
- (void)viewDidLoad
{
    [super viewDidLoad];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(chwlMatchesChanged:) name:CHWLMatchesChanged object:nil];
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
- (PSSpecifier *)createGroupSpecifierForApplicationSection:(ATLApplicationSection *)section
{
    PSSpecifier *group = [super createGroupSpecifierForApplicationSection:section];
    [group setProperty:(section.sectionType == SECTION_TYPE_HIDDEN ? @"隐藏应用" : @"应用程序") forKey:@"chwlGroupName"];
    return group;
}
- (NSMutableArray *)specifiers
{
    NSMutableArray *source = [super specifiers];
    if (objc_getAssociatedObject(source, &CHWLGroupedKey)) return source;
    NSMutableArray *grouped = [NSMutableArray new];
    NSMutableArray *rows = [NSMutableArray new];
    NSString *base = @"应用程序";
    for (PSSpecifier *item in source) {
        if (item.cellType == PSGroupCell) {
            [grouped addObjectsFromArray:CHWLGroupRows(rows, base)];
            [rows removeAllObjects];
            base = [item propertyForKey:@"chwlGroupName"] ?: @"应用程序";
        } else if ([item propertyForKey:@"applicationIdentifier"]) {
            [item setProperty:@([base isEqualToString:@"应用程序"]) forKey:@"chwlPrivilegeEligible"];
            [rows addObject:item];
        } else [grouped addObject:item];
    }
    [grouped addObjectsFromArray:CHWLGroupRows(rows, base)];
    objc_setAssociatedObject(grouped, &CHWLGroupedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    _specifiers = grouped;
    CHWLRememberListState(self);
    return grouped;
}
- (NSString *)previewStringForApplicationWithIdentifier:(NSString *)applicationID
{
    NSDictionary *section = [[self.specifier propertyForKey:@"sections"] firstObject];
    return CHWLConfigurationSummary(CHInjectionEnabled(preferences, applicationID, CHExecutablePathForApplication(applicationID)),
        [section[@"sectionType"] isEqualToString:@"Visible"],
        processPreferencesForApplication(preferences, applicationID));
}
+ (NSString *)previewStringForProcessPreferences:(NSDictionary *)processPreferences
{
    return [CHPListController previewStringForProcessPreferences:processPreferences];
}
@end
