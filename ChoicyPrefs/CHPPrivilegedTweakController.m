#import "CHPPrivilegedTweakController.h"
#import "CHPPreferences.h"
#import "CHPTweakList.h"
#import "CHPTweakInfo.h"
#import "CHPPackageInfo.h"
#import "CHWLData.h"
#import "CHWLListSupport.h"
#import "../Shared.h"

@implementation CHPPrivilegedTweakController

- (NSString *)topTitle { return @"特权插件"; }
- (NSString *)plistName { return nil; }

- (void)viewDidLoad
{
    [self applySearchControllerHideWhileScrolling:NO];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(matchesChanged:)
        name:CHWLMatchesChanged object:nil];
    [super viewDidLoad];
}

- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    extern void choicy_reloadPreferences(void);
    choicy_reloadPreferences();
    CHWLRefreshMatches();
    if (CHWLListStateChanged(self)) [self reloadSpecifiers];
}

- (void)matchesChanged:(NSNotification *)notification
{
    if (self.isViewLoaded && self.view.window && self.navigationController.topViewController == self) [self reloadSpecifiers];
    else _specifiers = nil;
}

- (NSMutableArray *)specifiers
{
    [super specifiers];
    if (!_specifiers) {
        _specifiers = [NSMutableArray new];
        PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
        [group setProperty:@"仅列出 UIKit 类插件。特权仅对“应用程序”中的普通应用生效，可绕过其注入开关及普通自定义名单，仍遵守全局插件配置、该应用的“自定义特权插件”和“禁用特权插件”设置。系统进程、隐藏应用和应用拓展不享有特权，须手动启用注入。修改后在目标下次启动时生效。" forKey:@"footerText"];
        [_specifiers addObject:group];
        CHPTweakList *list = [CHPTweakList sharedInstance];
        for (CHPTweakInfo *tweak in CHWLPrivilegeCandidates(list.tweakList)) {
            if ([list isTweakHiddenForAnyProcess:tweak]) continue;
            CHPPackageInfo *package = [CHPPackageInfo fetchPackageInfoForDylibName:tweak.dylibName];
            if (_searchKey.length && ![tweak.dylibName localizedStandardContainsString:_searchKey] &&
                ![package.name localizedStandardContainsString:_searchKey]) continue;
            PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:tweak.dylibName target:self
                set:@selector(setPrivilegedValue:specifier:) get:@selector(readPrivilegedValue:)
                detail:nil cell:PSSwitchCell edit:nil];
            [row setProperty:NSClassFromString(@"CHPSubtitleSwitch") forKey:@"cellClass"];
            [row setProperty:tweak.dylibName forKey:@"key"];
            [row setProperty:@YES forKey:@"chwlUIKitTweak"];
            [row setProperty:@YES forKey:@"enabled"];
            [row setProperty:@NO forKey:@"default"];
            if (package.name.length) [row setProperty:package.name forKey:@"subtitle"];
            [_specifiers addObject:row];
        }
        if (_specifiers.count == 1) {
            [_specifiers addObject:[PSSpecifier preferenceSpecifierNamed:
                (_searchKey.length ? @"未找到匹配插件" : @"未检测到 UIKit 类插件")
                target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil]];
        }
        CHWLRememberListState(self);
    }
    return _specifiers;
}

- (id)readPrivilegedValue:(PSSpecifier *)specifier
{
    return @(CHWLIsPrivilegedTweak(preferences, [specifier propertyForKey:@"key"],
        [[specifier propertyForKey:@"chwlUIKitTweak"] boolValue]));
}

- (void)setPrivilegedValue:(id)value specifier:(PSSpecifier *)specifier
{
    NSString *name = [specifier propertyForKey:@"key"];

    BOOL eligible = NO;
    for (CHPTweakInfo *tweak in [CHPTweakList sharedInstance].tweakList) {
        if ([tweak.dylibName isEqualToString:name]) { eligible = tweak.isUIKitTweak; break; }
    }
    if (!eligible || !name.length) return;
    NSMutableDictionary *latest = preferencesForWriting();
    NSMutableSet *names = [NSMutableSet setWithArray:CHWLPrivilegedTweakNames(latest)];
    if ([value boolValue]) [names addObject:name];
    else [names removeObject:name];
    latest[kChoicyPrefsKeyPrivilegedTweaks] = [names.allObjects sortedArrayUsingSelector:@selector(compare:)];
    writePreferences(latest);
    CHWLRememberListState(self);
    [self reloadSpecifier:specifier];
}

@end
