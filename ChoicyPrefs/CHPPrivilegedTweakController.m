#import "CHPPrivilegedTweakController.h"
#import "CHPPreferences.h"
#import "CHPTweakList.h"
#import "CHPTweakInfo.h"
#import "CHPPackageInfo.h"
#import "CHWLData.h"
#import "CHWLListSupport.h"
#import "CHPManualPrivilegedTweakController.h"
#import "../Shared.h"

@implementation CHPPrivilegedTweakController

- (NSString *)topTitle { return localize(@"PRIVILEGED_TWEAKS"); }
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
        [_specifiers addObject:[PSSpecifier groupSpecifierWithName:localize(@"MANUAL_RECOGNITION")]];
        PSSpecifier *manage = [PSSpecifier preferenceSpecifierNamed:localize(@"MANAGE_PRIVILEGED_TWEAKS") target:self
            set:nil get:nil detail:CHPManualPrivilegedTweakController.class cell:PSLinkCell edit:nil];
        [manage setProperty:NSClassFromString(@"CHWLLinkCell") forKey:@"cellClass"];
        [_specifiers addObject:manage];
        CHPTweakList *list = [CHPTweakList sharedInstance];
        NSSet *manualNames = [NSSet setWithArray:CHWLManualPrivilegedTweakNames(preferences)];
        for (CHPTweakInfo *tweak in list.tweakList) {
            if (!tweak.isUIKitTweak && [manualNames containsObject:tweak.dylibName]) [self appendTweak:tweak];
        }
        PSSpecifier *defaultsGroup = [PSSpecifier groupSpecifierWithName:localize(@"DEFAULT_RECOGNITION")];
        [defaultsGroup setProperty:localize(@"PRIVILEGED_TWEAKS_FOOTER") forKey:@"footerText"];
        [_specifiers addObject:defaultsGroup];
        NSUInteger defaultsStart = _specifiers.count;
        for (CHPTweakInfo *tweak in CHWLPrivilegeCandidates(list.tweakList)) {
            [self appendTweak:tweak];
        }
        if (_specifiers.count == defaultsStart) {
            [_specifiers addObject:[PSSpecifier preferenceSpecifierNamed:
                (_searchKey.length ? localize(@"NO_MATCHING_TWEAKS") : localize(@"NO_UIKIT_TWEAKS"))
                target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil]];
        }
        CHWLRememberListState(self);
    }
    return _specifiers;
}

- (void)appendTweak:(CHPTweakInfo *)tweak
{
    if ([CHPTweakList.sharedInstance isTweakHiddenForAnyProcess:tweak]) return;
    CHPPackageInfo *package = [CHPPackageInfo fetchPackageInfoForDylibName:tweak.dylibName];
    if (_searchKey.length && ![tweak.dylibName localizedStandardContainsString:_searchKey] &&
        ![package.name localizedStandardContainsString:_searchKey]) return;
    PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:tweak.dylibName target:self
        set:@selector(setPrivilegedValue:specifier:) get:@selector(readPrivilegedValue:)
        detail:nil cell:PSSwitchCell edit:nil];
    [row setProperty:NSClassFromString(@"CHPSubtitleSwitch") forKey:@"cellClass"];
    [row setProperty:tweak.dylibName forKey:@"key"];
    [row setProperty:@(tweak.isUIKitTweak) forKey:@"chwlUIKitTweak"];
    [row setProperty:@YES forKey:@"enabled"];
    [row setProperty:@NO forKey:@"default"];
    [self configureTargetInspectionForSpecifier:row tweak:tweak];
    if (package.name.length) [row setProperty:package.name forKey:@"subtitle"];
    [_specifiers addObject:row];
}

- (id)readPrivilegedValue:(PSSpecifier *)specifier
{
    return @(CHWLIsPrivilegedTweak(preferences, [specifier propertyForKey:@"key"],
        [[specifier propertyForKey:@"chwlUIKitTweak"] boolValue]));
}

- (void)setPrivilegedValue:(id)value specifier:(PSSpecifier *)specifier
{
    NSString *name = [specifier propertyForKey:@"key"];
    NSMutableDictionary *latest = preferencesForWriting();
                                                                                 
    BOOL eligible = NO;
    for (CHPTweakInfo *tweak in [CHPTweakList sharedInstance].tweakList) {
        if ([tweak.dylibName isEqualToString:name] &&
            ![CHPTweakList.sharedInstance isTweakHiddenForAnyProcess:tweak]) {
            eligible = CHWLPrivilegeCandidate(latest, name, tweak.isUIKitTweak);
            break;
        }
    }
    if (!eligible || !name.length) return;
    NSMutableSet *names = [NSMutableSet setWithArray:CHWLPrivilegedTweakNames(latest)];
    if ([value boolValue]) [names addObject:name];
    else [names removeObject:name];
    latest[kChoicyPrefsKeyPrivilegedTweaks] = [names.allObjects sortedArrayUsingSelector:@selector(compare:)];
    writePreferences(latest);
    CHWLRememberListState(self);
    [self reloadSpecifier:specifier];
}

@end
