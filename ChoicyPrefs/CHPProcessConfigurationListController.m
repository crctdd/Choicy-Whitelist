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

#import "CHPProcessConfigurationListController.h"
#import "CHPProcessTweakConfigurationController.h"

#import <Preferences/PSSpecifier.h>
#import "../Shared.h"
#import "CHPTweakList.h"
#import "CHPTweakInfo.h"
#import "CHPMachoParser.h"
#import "CHPRootListController.h"
#import "CHPPackageInfo.h"
#import "CHWLListSupport.h"
#import "CHWLData.h"
#import "CHWLFrameworkMatches.h"
#import "CoreServices.h"
#import "CHPPreferences.h"
#import "CHPPackageInfo.h"
#import "CHPApplicationPlugInsListController.h"
#import <MobileCoreServices/LSBundleProxy.h>
#import <MobileCoreServices/LSPlugInKitProxy.h>
#import "../ChoicyPrefsMigrator.h"

@interface PSSpecifier ()
@property (nonatomic,retain) NSArray *values;
@end

@interface CHPProcessConfigurationListController ()
- (BOOL)hasActivePrivilegedTweaks;
@end

@implementation CHPProcessConfigurationListController

+ (NSString *)executablePathForBundleProxy:(LSBundleProxy *)bundleProxy
{
	NSString *bundleExecutablePath = nil;
	if ([bundleProxy respondsToSelector:@selector(canonicalExecutablePath)]) {
		bundleExecutablePath = bundleProxy.canonicalExecutablePath;
	}

	if (!bundleExecutablePath) {
		NSString *bundleExecutable = bundleProxy.bundleExecutable;
		if (bundleExecutable) {
			bundleExecutablePath = [bundleProxy.bundleURL URLByAppendingPathComponent:bundleExecutable].path;
		}
	}

	if (!bundleExecutablePath && [bundleProxy isKindOfClass:[LSPlugInKitProxy class]]) {
		if (NSClassFromString(@"LSApplicationExtensionRecord")) {
			LSApplicationExtensionRecord *appexRecord = [bundleProxy valueForKey:@"_appexRecord"];
			bundleExecutablePath = appexRecord.executableURL.path;
		}
		else {
			NSString *bundleExecutable = ((LSPlugInKitProxy *)bundleProxy).infoPlist[@"CFBundleExecutable"];
			if (bundleExecutable) {
				bundleExecutablePath = [bundleProxy.bundleURL URLByAppendingPathComponent:bundleExecutable].path;
			}
		}
	}

	return bundleExecutablePath;
}

- (NSString *)executableName
{
	return [self executablePath].lastPathComponent;
}

- (NSString *)executablePath
{
	NSString *executablePath = [[self specifier] propertyForKey:@"executablePath"];
	if (executablePath) return executablePath;

	if (_bundleProxy) {
		return [[self class] executablePathForBundleProxy:_bundleProxy];
	}

	return nil;
}

- (NSString *)applicationIdentifier
{
	return _appIdentifier;
}

- (NSString *)keyForPreferences
{
	if (_appIdentifier) return _appIdentifier;
	if (_pluginIdentifier) return _pluginIdentifier;
	return [self executableName];
}

- (void)respring
{
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.crctdd.choicy-whitelist/respring"), NULL, NULL, YES);
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	if ([_appIdentifier isEqualToString:kSpringboardBundleID]) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:localize(@"RESPRING") style:UIBarButtonItemStylePlain target:self action:@selector(respring)];
	}

	[self updateSwitchesAvailability];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(chwlMatchesChanged:) name:CHWLMatchesChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(chwlFrameworkMatchesChanged:) name:CHWLFrameworkMatchesChanged object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    extern void choicy_reloadPreferences(void);
    choicy_reloadPreferences();
    CHWLRefreshMatches();
    if (CHWLListStateChanged(self)) [self reloadSpecifiers];
}

- (NSString *)topTitle
{
	return [self specifier].name;
}

- (NSString *)dictionaryName
{
	if (_appIdentifier || _pluginIdentifier) {
		return kChoicyPrefsKeyAppSettings;
	}
	else {
		return kChoicyPrefsKeyDaemonSettings;
	}
}

- (NSString *)plistName
{
	return @"ApplicationDaemon";
}

- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)chwlFrameworkMatchesChanged:(NSNotification *)note
{
    if (!CHWLUsesFrameworkMatching(self.specifier) ||
        ![note.object containsObject:self.executablePath.stringByStandardizingPath]) return;
    if (self.isViewLoaded && self.view.window && self.navigationController.topViewController == self) [self reloadSpecifiers];
    else _specifiers = nil;
}
- (void)chwlMatchesChanged:(NSNotification *)note
{
    if (self.isViewLoaded && self.view.window && self.navigationController.topViewController == self) [self reloadSpecifiers];
    else _specifiers = nil;
}
- (NSMutableArray *)specifiers
{
    if (!_specifiers) {
        _appIdentifier = [self.specifier propertyForKey:@"applicationIdentifier"];
        _pluginIdentifier = [self.specifier propertyForKey:@"pluginIdentifier"];
        if (_appIdentifier) _bundleProxy = (LSBundleProxy *)[LSApplicationProxy applicationProxyForIdentifier:_appIdentifier];
        else if (_pluginIdentifier) _bundleProxy = (LSBundleProxy *)[LSPlugInKitProxy pluginKitProxyForIdentifier:_pluginIdentifier];
        [self readPreferences];
        NSMutableArray *base = [[super specifiers] mutableCopy];
        _specifiers = [NSMutableArray new];
        BOOL privilegeEligible = CHWLPrivilegeEligibleForSpecifier(self.specifier);
        for (PSSpecifier *baseItem in base) {
            PSSpecifier *item = baseItem;
            if (!privilegeEligible && ([[item propertyForKey:@"id"] isEqual:@"DISABLE_PRIVILEGE_GROUP"] ||
                [[item propertyForKey:@"key"] isEqual:kChoicyProcessPrefsKeyDisablePrivilegedTweaks] ||
                [[item propertyForKey:@"id"] isEqual:@"CUSTOM_PRIVILEGE_GROUP"] ||
                [[item propertyForKey:@"key"] isEqual:kChoicyProcessPrefsKeyCustomPrivilegedConfigurationEnabled])) continue;
            if ([[item propertyForKey:@"id"] isEqual:@"GLOBAL_OVERRIDE_GROUP"] ||
                [[item propertyForKey:@"key"] isEqual:kChoicyProcessPrefsKeyOverwriteGlobalTweakConfiguration]) continue;
            NSString *key = [item propertyForKey:@"key"];
            if ([key isEqual:kChoicyProcessPrefsKeyCustomTweakConfigurationEnabled] ||
                [key isEqual:kChoicyProcessPrefsKeyCustomPrivilegedConfigurationEnabled]) {
                PSSpecifier *link = [PSSpecifier preferenceSpecifierNamed:item.name target:self set:nil
                    get:@selector(readCustomConfigurationStatus:) detail:CHPProcessTweakConfigurationController.class
                    cell:PSLinkListCell edit:nil];
                for (NSString *property in @[@"id", @"label", @"key"]) {
                    id value = [item propertyForKey:property];
                    if (value) [link setProperty:value forKey:property];
                }
                link.identifier = [item propertyForKey:@"id"];
                [link setProperty:self.specifier forKey:@"chwlTargetSpecifier"];
                [link setProperty:@([key isEqual:kChoicyProcessPrefsKeyCustomPrivilegedConfigurationEnabled]) forKey:@"chwlPrivilegedPage"];
                [link setProperty:@(CHWLCustomConfigurationAvailable([[link propertyForKey:@"chwlPrivilegedPage"] boolValue],
                    CHInjectionEnabled(preferences, _appIdentifier ?: _pluginIdentifier, self.executablePath), privilegeEligible,
                    _processPreferences)) forKey:@"enabled"];
                item = link;
            }
            [_specifiers addObject:item];
        }
        PSSpecifier *enabled = [self specifierForID:@"ENABLE_TWEAK_INJECTION"];
        BOOL forced = CHInjectionIsForced(_appIdentifier ?: _pluginIdentifier, self.executablePath);
        [enabled setProperty:@(!forced) forKey:@"enabled"];
        PSSpecifier *disablePrivilege = [self specifierForID:@"DISABLE_PRIVILEGED_TWEAKS"];
        if (disablePrivilege) [disablePrivilege setProperty:@(CHDisablePrivilegeSwitchEditable(
            CHInjectionEnabled(preferences, _appIdentifier ?: _pluginIdentifier, self.executablePath),
            [self hasActivePrivilegedTweaks])) forKey:@"enabled"];
        PSSpecifier *custom = [self specifierForID:@"CUSTOM_TWEAK_CONFIGURATION"];
        [custom setProperty:@(CHInjectionEnabled(preferences, _appIdentifier ?: _pluginIdentifier, self.executablePath)) forKey:@"enabled"];
        if ([preferences[kChoicyPrefsKeyGlobalDeniedTweaks] count]) {
            for (PSSpecifier *item in base) {
                if ([[item propertyForKey:@"id"] isEqual:@"GLOBAL_OVERRIDE_GROUP"] ||
                    [[item propertyForKey:@"key"] isEqual:kChoicyProcessPrefsKeyOverwriteGlobalTweakConfiguration]) [_specifiers addObject:item];
            }
        }
        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:localize(@"MATCHING_TWEAKS")];
        BOOL includeFrameworks = CHWLUsesFrameworkMatching(self.specifier);
        CHWLRequestFrameworkMatchesForSpecifier(self.specifier);
        [group setProperty:(includeFrameworks ?
            localize(@"MATCHING_FRAMEWORK_FOOTER") :
            localize(@"MATCHING_EXPLICIT_FOOTER")) forKey:@"footerText"];
        [_specifiers addObject:group];
        NSArray *matches = CHWLMatchesForSpecifier(self.specifier);
        NSMutableArray<NSString *> *names = [NSMutableArray new];
        for (CHPTweakInfo *tweak in matches) {
            CHPPackageInfo *package = [CHPPackageInfo fetchPackageInfoForDylibName:tweak.dylibName];
            NSString *name = package.name.length ? package.name : tweak.dylibName;
            [names addObject:name];
        }
        NSString *text = names.count ? [names componentsJoinedByString:@"\n"] :
            (includeFrameworks && !CHWLFrameworkAnalysisFinished(self.executablePath) ? localize(@"DETECTING_FRAMEWORK_MATCHES") :
            (includeFrameworks && CHWLFrameworkAnalysisFailed(self.executablePath) ? localize(@"FRAMEWORK_ANALYSIS_INCOMPLETE") :
            (matches ? localize(@"NO_MATCHING_INJECTION") : localize(@"DETECTING_INJECTION"))));
        PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
        [row setProperty:NSClassFromString(@"CHWLPluginCell") forKey:@"cellClass"];
        [row setProperty:text forKey:@"chwlBoxText"];
        [row setProperty:@YES forKey:@"enabled"];
        [row setProperty:@(MIN(192, MAX(88, names.count * 25 + 40))) forKey:@"height"];
        [_specifiers addObject:row];
        CHWLRememberListState(self);
    }
    return _specifiers;
}

- (BOOL)hasActivePrivilegedTweaks
{
    CHPTweakList *list = CHPTweakList.sharedInstance;
    for (CHPTweakInfo *tweak in list.tweakList) {
        if (![list isTweakHiddenForAnyProcess:tweak] &&
            CHWLIsPrivilegedTweak(preferences, tweak.dylibName, tweak.isUIKitTweak)) return YES;
    }
    return NO;
}

- (void)reloadSpecifiers
{
	[super reloadSpecifiers];
	[self updateSwitchesAvailability];
}

- (void)updateSwitchesAvailability
{
    PSSpecifier *enabled = [self specifierForID:@"ENABLE_TWEAK_INJECTION"];
    [enabled setProperty:@(!CHInjectionIsForced(_appIdentifier ?: _pluginIdentifier, self.executablePath)) forKey:@"enabled"];
                                                                                            
    PSSpecifier *custom = [self specifierForID:@"CUSTOM_TWEAK_CONFIGURATION"];
    [custom setProperty:@(CHInjectionEnabled(preferences, _appIdentifier ?: _pluginIdentifier, self.executablePath)) forKey:@"enabled"];
    PSSpecifier *disablePrivilege = [self specifierForID:@"DISABLE_PRIVILEGED_TWEAKS"];
    if (disablePrivilege) [disablePrivilege setProperty:@(CHDisablePrivilegeSwitchEditable(
        CHInjectionEnabled(preferences, _appIdentifier ?: _pluginIdentifier, self.executablePath),
        [self hasActivePrivilegedTweaks])) forKey:@"enabled"];
    PSSpecifier *privilege = [self specifierForID:@"CUSTOM_PRIVILEGED_CONFIGURATION"];
    if (privilege) [privilege setProperty:@(CHWLCustomConfigurationAvailable(YES,
        CHInjectionEnabled(preferences, _appIdentifier ?: _pluginIdentifier, self.executablePath),
        CHWLPrivilegeEligibleForSpecifier(self.specifier), _processPreferences)) forKey:@"enabled"];
    if (privilege) [self reloadSpecifier:privilege];
    if (enabled) [self reloadSpecifier:enabled];
    if (custom) [self reloadSpecifier:custom];
    if (disablePrivilege) [self reloadSpecifier:disablePrivilege];
}

- (void)readPreferences
{
	[self readAppDaemonSettingsFromMainPropertyList];
}

- (void)writePreferences
{
	[self writeAppDaemonSettingsToMainPropertyList];
}

- (void)writePreferenceValue:(id)value key:(NSString *)key
{
	_processPreferences = [CHWLProcessPreferencesBySetting(_processPreferences, key, value) mutableCopy];
	[self writePreferences];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier
{
	NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqual:kChoicyProcessPrefsKeyTweakInjectionEnabled] && CHInjectionIsForced(_appIdentifier ?: _pluginIdentifier, self.executablePath)) return;
    if ([key isEqual:kChoicyProcessPrefsKeyDisablePrivilegedTweaks] &&
        (!CHWLPrivilegeEligibleForSpecifier(self.specifier) ||
        !CHDisablePrivilegeSwitchEditable(CHInjectionEnabled(preferences, _appIdentifier ?: _pluginIdentifier, self.executablePath),
            [self hasActivePrivilegedTweaks]))) {
        [self updateSwitchesAvailability];
        return;
    }
    if ([key isEqual:kChoicyProcessPrefsKeyCustomTweakConfigurationEnabled] &&
        !CHInjectionEnabled(preferences, _appIdentifier ?: _pluginIdentifier, self.executablePath)) {
        [self updateSwitchesAvailability];
        return;
    }
	[self writePreferenceValue:value key:key];
    [self reloadSpecifiers];
}

- (id)readCustomConfigurationStatus:(PSSpecifier *)row
{
    return CHWLCustomConfigurationActive([[row propertyForKey:@"chwlPrivilegedPage"] boolValue],
        CHInjectionEnabled(preferences, _appIdentifier ?: _pluginIdentifier, self.executablePath),
        CHWLPrivilegeEligibleForSpecifier(self.specifier), _processPreferences) ? localize(@"STATUS_ENABLED") : @"";
}

- (id)readPreferenceValue:(PSSpecifier *)specifier
{
    if ([[specifier propertyForKey:@"key"] isEqual:kChoicyProcessPrefsKeyTweakInjectionEnabled]) {
        return @(CHInjectionEnabled(preferences, _appIdentifier ?: _pluginIdentifier, self.executablePath));
    }
	id obj = [_processPreferences objectForKey:[[specifier properties] objectForKey:@"key"]];
	if (!obj) {
		obj = [specifier propertyForKey:@"default"];
	}
	return obj;
}

- (void)readAppDaemonSettingsFromMainPropertyList
{
	NSDictionary *appDaemonSettingsDict = [preferences objectForKey:[self dictionaryName]];

	_processPreferences = [[appDaemonSettingsDict objectForKey:[self keyForPreferences]] mutableCopy];
	if (!_processPreferences) {
		_processPreferences = [NSMutableDictionary new];
	}
}

- (void)writeAppDaemonSettingsToMainPropertyList
{
	NSMutableDictionary *mutablePrefs = preferencesForWriting();
	NSMutableDictionary *appDaemonSettingsDict = [[mutablePrefs objectForKey:[self dictionaryName]] mutableCopy] ?: [NSMutableDictionary new];
	appDaemonSettingsDict[[self keyForPreferences]] = [_processPreferences copy];
	mutablePrefs[[self dictionaryName]] = [appDaemonSettingsDict copy];
	writePreferences(mutablePrefs);
}

@end
