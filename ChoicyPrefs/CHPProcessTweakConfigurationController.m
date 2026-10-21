#import "CHPProcessTweakConfigurationController.h"
#import "CHPPreferences.h"
#import "CHPTweakList.h"
#import "CHPTweakInfo.h"
#import "CHPPackageInfo.h"
#import "CHPRootListController.h"
#import "CHWLData.h"
#import "CHWLListSupport.h"
#import "CHPMachoParser.h"
#import "CHWLFrameworkMatches.h"
#import "../Shared.h"

@interface PSSpecifier ()
@property (nonatomic, retain) NSArray *values;
@end

@interface CHPProcessTweakConfigurationController ()
@property (nonatomic, copy) NSDictionary *analysis;
@property (nonatomic) BOOL showOtherTweaks;
@property (nonatomic) BOOL refreshAnalysis;
@property (nonatomic) BOOL loading;
@property (nonatomic) NSUInteger request;
@end

@implementation CHPProcessTweakConfigurationController

- (NSString *)plistName { return nil; }
- (BOOL)isPrivilegedPage { return [[self.specifier propertyForKey:@"chwlPrivilegedPage"] boolValue]; }
- (PSSpecifier *)targetSpecifier { return [self.specifier propertyForKey:@"chwlTargetSpecifier"]; }
- (NSString *)topTitle { return self.isPrivilegedPage ? @"自定义特权插件" : localize(@"CUSTOM_TWEAK_CONFIGURATION"); }
- (NSString *)dictionaryName { return CHWLIdentifier(self.targetSpecifier).length ? kChoicyPrefsKeyAppSettings : kChoicyPrefsKeyDaemonSettings; }
- (NSString *)settingsKey { return CHWLIdentifier(self.targetSpecifier) ?: CHWLExecutable(self.targetSpecifier).lastPathComponent; }
- (NSString *)enabledKey { return self.isPrivilegedPage ? @CH_CUSTOM_PRIVILEGE_ENABLED_KEY : kChoicyProcessPrefsKeyCustomTweakConfigurationEnabled; }
- (NSString *)modeKey { return self.isPrivilegedPage ? @CH_CUSTOM_PRIVILEGE_MODE_KEY : kChoicyProcessPrefsKeyAllowDenyMode; }
- (NSString *)allowedKey { return self.isPrivilegedPage ? @CH_CUSTOM_PRIVILEGE_ALLOWED_KEY : kChoicyProcessPrefsKeyAllowedTweaks; }
- (NSString *)deniedKey { return self.isPrivilegedPage ? @CH_CUSTOM_PRIVILEGE_DENIED_KEY : kChoicyProcessPrefsKeyDeniedTweaks; }
- (NSDictionary *)settings
{
    NSString *key = self.settingsKey;
    id settings = key.length ? preferences[self.dictionaryName][key] : nil;
    return [settings isKindOfClass:NSDictionary.class] ? settings : @{};
}
- (BOOL)available
{
    return CHWLCustomConfigurationAvailable(self.isPrivilegedPage,
        CHInjectionEnabled(preferences, CHWLIdentifier(self.targetSpecifier), CHWLExecutable(self.targetSpecifier)),
        CHWLPrivilegeEligibleForSpecifier(self.targetSpecifier), self.settings);
}

- (void)viewDidLoad
{
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
- (void)matchesChanged:(NSNotification *)note
{
    self.analysis = nil;
    self.loading = NO;
    self.request++;
    if (self.isViewLoaded && self.view.window && self.navigationController.topViewController == self) [self reloadSpecifiers];
    else _specifiers = nil;
}

- (void)loadMatchesIfNeeded
{
    if (self.isPrivilegedPage || self.analysis || self.loading) return;
    NSString *path = CHWLExecutable(self.targetSpecifier);
    NSDictionary *cached = self.refreshAnalysis ? nil :
        [CHPTweakList.sharedInstance cachedCandidateAnalysisForExecutableAtPath:path];
    if (cached) { self.analysis = cached; return; }
    self.loading = YES;
    NSUInteger request = ++self.request;
    BOOL refresh = self.refreshAnalysis;
    self.refreshAnalysis = NO;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        if (refresh) {
            [[CHPMachoParser sharedInstance] invalidateAnalysisCaches];
            [CHPTweakList.sharedInstance invalidateCandidateAnalysisForExecutableAtPath:path];
        }
        NSDictionary *analysis = [[CHPTweakList sharedInstance] candidateAnalysisForExecutableAtPath:path];
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) controller = weakSelf;
            if (!controller || controller.request != request) return;
            controller.analysis = analysis;
            controller.loading = NO;
            CHWLPublishFrameworkAnalysis(path, analysis);
            if (controller.isViewLoaded && controller.view.window && controller.navigationController.topViewController == controller) [controller reloadSpecifiers];
            else controller->_specifiers = nil;
        });
    });
}

- (NSArray *)candidates
{
    CHPTweakList *list = CHPTweakList.sharedInstance;
    NSArray *source = list.tweakList;
    NSMutableArray *result = [NSMutableArray new];
    for (CHPTweakInfo *tweak in CHWLConfigurationCandidates(source, preferences,
        CHWLPrivilegeEligibleForSpecifier(self.targetSpecifier), self.isPrivilegedPage)) {
        if ([kAlwaysInjectGlobal containsObject:tweak.dylibName]) continue;
        NSString *app = [self.targetSpecifier propertyForKey:@"applicationIdentifier"];
        if (app.length && [list isTweak:tweak hiddenForApplicationWithIdentifier:app]) continue;
        if (self.isPrivilegedPage && [list isTweakHiddenForAnyProcess:tweak]) continue;
        [result addObject:tweak];
    }
    return result.copy;
}

- (NSDictionary *)candidateGroups
{
    return CHWLCustomCandidateGroups(self.candidates, self.analysis[@"matches"], preferences,
        CHWLPrivilegeEligibleForSpecifier(self.targetSpecifier), self.settings);
}

- (void)appendTweaks:(NSArray *)tweaks unconfirmed:(BOOL)unconfirmed
{
    (void)unconfirmed;
    BOOL editable = self.available && [self.settings[self.enabledKey] boolValue];
    for (CHPTweakInfo *tweak in tweaks) {
        BOOL loadedEarly = [dylibsBeforeChoicy containsObject:tweak.dylibName];
        PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:tweak.dylibName target:self
            set:@selector(setTweakValue:specifier:) get:@selector(tweakValue:)
            detail:nil cell:PSSwitchCell edit:nil];
        [row setProperty:NSClassFromString(@"CHPSubtitleSwitch") forKey:@"cellClass"];
        [row setProperty:tweak.dylibName forKey:@"key"];
        [row setProperty:@(loadedEarly) forKey:@"chwlLoadedEarly"];
        [row setProperty:@(editable && !loadedEarly) forKey:@"enabled"];
        CHPPackageInfo *package = [CHPPackageInfo fetchPackageInfoForDylibName:tweak.dylibName];
        NSString *subtitle = package.name.length ? [NSString stringWithFormat:@"%@: %@", localize(@"PACKAGE"), package.name] : @"";
        if (subtitle.length) [row setProperty:subtitle forKey:@"subtitle"];
        [_specifiers addObject:row];
    }
}

- (void)showOtherCandidates
{
    self.showOtherTweaks = YES;
    [self reloadSpecifiers];
}

- (void)retryAnalysis
{
    self.analysis = nil;
    self.loading = NO;
    self.request++;
    self.refreshAnalysis = YES;
    [CHPTweakList.sharedInstance invalidateCandidateAnalysisForExecutableAtPath:CHWLExecutable(self.targetSpecifier)];
    CHWLInvalidateFrameworkAnalysis(CHWLExecutable(self.targetSpecifier));
    [self reloadSpecifiers];
}

- (NSMutableArray *)specifiers
{
    [super specifiers];
    if (!_specifiers) {
        _specifiers = [NSMutableArray new];
        [self loadMatchesIfNeeded];
        BOOL available = self.available;
        BOOL enabled = [self.settings[self.enabledKey] boolValue];
        [_specifiers addObject:[PSSpecifier emptyGroupSpecifier]];
        PSSpecifier *toggle = [PSSpecifier preferenceSpecifierNamed:@"启用" target:self
            set:@selector(setConfigurationValue:specifier:) get:@selector(configurationValue:)
            detail:nil cell:PSSwitchCell edit:nil];
        [toggle setProperty:self.enabledKey forKey:@"key"];
        [toggle setProperty:@NO forKey:@"default"];
        [toggle setProperty:@(available && (self.isPrivilegedPage || self.analysis || enabled)) forKey:@"enabled"];
        [_specifiers addObject:toggle];
        PSSpecifier *mode = [PSSpecifier preferenceSpecifierNamed:nil target:self
            set:@selector(setConfigurationValue:specifier:) get:@selector(configurationValue:)
            detail:nil cell:PSSegmentCell edit:nil];
        mode.values = @[@1, @2];
        mode.titleDictionary = @{@1:localize(@"ALLOW"), @2:localize(@"DENY")};
        [mode setProperty:self.modeKey forKey:@"key"];
        [mode setProperty:@1 forKey:@"default"];
        [mode setProperty:@(available && enabled) forKey:@"enabled"];
        [_specifiers addObject:mode];
        PSSpecifier *listGroup = [PSSpecifier emptyGroupSpecifier];
        [_specifiers addObject:listGroup];
        if (self.isPrivilegedPage) {
            [self appendTweaks:self.candidates unconfirmed:NO];
        } else if (!self.analysis) {
            [_specifiers addObject:[PSSpecifier preferenceSpecifierNamed:@"正在检测插件…"
                target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil]];
        } else {
            NSDictionary *groups = self.candidateGroups;
            BOOL complete = [self.analysis[@"complete"] boolValue];
            [listGroup setProperty:(complete ?
                @"按目标标识、可执行文件及可读取的框架依赖匹配。静态检测无法覆盖所有动态加载；缺少的插件可从“显示其他插件”中手动配置。" :
                @"部分依赖或框架未能识别，当前匹配结果不完整。已保留可确认的结果，并展开待确认插件供手动配置；不会自动放行或清空名单。") forKey:@"footerText"];
            [self appendTweaks:groups[@"matched"] unconfirmed:NO];
            if ([groups[@"saved"] count]) {
                [_specifiers addObject:[PSSpecifier groupSpecifierWithName:@"已保存的其他插件"]];
                [self appendTweaks:groups[@"saved"] unconfirmed:YES];
            }
            if ([groups[@"other"] count] || !complete) {
                if (self.showOtherTweaks || !complete) {
                    PSSpecifier *other = [PSSpecifier groupSpecifierWithName:@"其他插件（未确认匹配）"];
                    [other setProperty:@"这些条目仅供手动配置，不代表插件指定注入此目标。勾选后也只有符合插件原有注入条件时才可能加载。" forKey:@"footerText"];
                    [_specifiers addObject:other];
                    if (!complete) {
                        PSSpecifier *retry = [PSSpecifier preferenceSpecifierNamed:@"重新检测插件"
                            target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
                        retry.buttonAction = @selector(retryAnalysis);
                        [_specifiers addObject:retry];
                    }
                    [self appendTweaks:groups[@"other"] unconfirmed:YES];
                } else {
                    PSSpecifier *more = [PSSpecifier preferenceSpecifierNamed:@"显示其他插件（未确认匹配）"
                        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
                    more.buttonAction = @selector(showOtherCandidates);
                    [_specifiers addObject:more];
                }
            }
        }
        if (!self.candidates.count && (self.isPrivilegedPage || self.analysis)) {
            [_specifiers addObject:[PSSpecifier preferenceSpecifierNamed:@"暂无可配置的插件"
                target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil]];
        }
        BOOL early = NO;
        for (CHPTweakInfo *tweak in self.candidates) {
            if ([dylibsBeforeChoicy containsObject:tweak.dylibName]) { early = YES; break; }
        }
        if (early) {
            PSSpecifier *notice = [PSSpecifier preferenceSpecifierNamed:localize(@"GREYED_OUT_ENTRIES")
                target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
            notice.buttonAction = @selector(presentLoadingWarning);
            [_specifiers addObject:notice];
        }
        CHWLRememberListState(self);
    }
    return _specifiers;
}

- (void)presentLoadingWarning { presentNotLoadingFirstWarning(self, NO); }
- (id)configurationValue:(PSSpecifier *)row { return self.settings[[row propertyForKey:@"key"]] ?: [row propertyForKey:@"default"]; }
- (BOOL)denyMode { return [self.settings[self.modeKey] integerValue] == 2; }
- (id)tweakValue:(PSSpecifier *)row
{
    if ([[row propertyForKey:@"chwlLoadedEarly"] boolValue]) return @(!self.denyMode);
    id list = self.settings[self.denyMode ? self.deniedKey : self.allowedKey];
    return @([list isKindOfClass:NSArray.class] && [list containsObject:[row propertyForKey:@"key"]]);
}

- (void)saveSettings:(NSDictionary *)settings inPreferences:(NSMutableDictionary *)latest
{
    if (!self.settingsKey.length) return;
    NSMutableDictionary *targets = [latest[self.dictionaryName] mutableCopy] ?: [NSMutableDictionary new];
    targets[self.settingsKey] = settings;
    latest[self.dictionaryName] = targets.copy;
    writePreferences(latest);
    [self reloadSpecifiers];
}
- (void)setConfigurationValue:(id)value specifier:(PSSpecifier *)row
{
    NSMutableDictionary *latest = preferencesForWriting();
    preferences = latest.copy;
    if (!self.available) { [self reloadSpecifiers]; return; }
    NSString *key = [row propertyForKey:@"key"];
    BOOL isEnable = [key isEqual:self.enabledKey];
    if (!isEnable && ![self.settings[self.enabledKey] boolValue]) return;
    if (!self.isPrivilegedPage && !self.analysis && isEnable && [value boolValue] &&
        ![self.settings[self.enabledKey] boolValue]) { [self reloadSpecifiers]; return; }
    NSDictionary *settings = self.settings;
    if (self.isPrivilegedPage && isEnable && [value boolValue]) {
        settings = CHWLInitializePrivilegedConfiguration(settings, [self.candidates valueForKey:@"dylibName"]);
    }
    settings = CHWLProcessPreferencesBySetting(settings, key, value);
    [self saveSettings:settings inPreferences:latest];
}
- (void)setTweakValue:(id)value specifier:(PSSpecifier *)row
{
    NSMutableDictionary *latest = preferencesForWriting();
    preferences = latest.copy;
    NSString *name = [row propertyForKey:@"key"];
    if (!self.available || ![self.settings[self.enabledKey] boolValue] ||
        [dylibsBeforeChoicy containsObject:name] || ![[self.candidates valueForKey:@"dylibName"] containsObject:name]) {
        [self reloadSpecifiers];
        return;
    }
    NSString *key = self.denyMode ? self.deniedKey : self.allowedKey;
    id saved = self.settings[key];
    NSMutableOrderedSet *names = [NSMutableOrderedSet orderedSetWithArray:[saved isKindOfClass:NSArray.class] ? saved : @[]];
    if ([value boolValue]) [names addObject:name]; else [names removeObject:name];
    [self saveSettings:CHWLProcessPreferencesBySetting(self.settings, key, names.array) inPreferences:latest];
}

@end
