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

#import "Shared.h"
#import "CHApplicationScope.h"
#import "roothide.h"
#import <MobileCoreServices/LSApplicationProxy.h>
#import "ChoicyPrefs/CoreServices.h"

static NSString *CHPrivatePath(NSString *name)
{
    NSString *path = jbroot([@"/var/mobile/Library/Preferences" stringByAppendingPathComponent:name]);
    if (![path isAbsolutePath] || [path hasPrefix:@"/var/mobile/Library/Preferences/"]) return nil;
    return path;
}

NSString *CHPreferencesPath(void)
{
    return CHPrivatePath(@"com.crctdd.choicy-whitelist.plist");
}

NSString *CHProcessCachePath(void)
{
    return CHPrivatePath(@"com.crctdd.choicy-whitelist-processpage.plist");
}

NSString *CHExecutablePathForApplication(NSString *identifier)
{
    if (!identifier.length) return nil;
    LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:identifier];
    if ([proxy respondsToSelector:@selector(canonicalExecutablePath)] && proxy.canonicalExecutablePath.length) {
        return proxy.canonicalExecutablePath;
    }
    return proxy.bundleExecutable.length ? [proxy.bundleURL.path stringByAppendingPathComponent:proxy.bundleExecutable] : nil;
}

BOOL CHIsJailbreakApp(NSString *identifier, NSString *executablePath)
{
    NSString *directory = executablePath.stringByDeletingLastPathComponent;
    if (!identifier.length || ![directory.pathExtension isEqualToString:@"app"]) return NO;
    NSString *candidate = [jbroot(@"/Applications") stringByAppendingPathComponent:directory.lastPathComponent];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[candidate stringByAppendingPathComponent:@"Info.plist"]];
    return [info[@"CFBundleIdentifier"] isEqual:identifier];
}

BOOL CHInjectionIsForced(NSString *identifier, NSString *executablePath)
{
    return CHForcedInjection(identifier.UTF8String, executablePath.lastPathComponent.UTF8String);
}

BOOL CHApplicationSupportsPrivilege(NSString *identifier)
{
    if (!identifier.length) return NO;
    LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:identifier];
    if (!proxy || ![proxy.bundleURL.path.pathExtension isEqual:@"app"]) return NO;
     
    NSArray *recordTags = nil;
    BOOL launchProhibited = NO;
    if ([proxy respondsToSelector:@selector(correspondingApplicationRecord)]) {
        LSApplicationRecord *record = proxy.correspondingApplicationRecord;
        recordTags = record.appTags;
        launchProhibited = record.launchProhibited;
    }
    NSArray *proxyTags = [proxy respondsToSelector:@selector(appTags)] ? proxy.appTags : nil;
    if ([proxy respondsToSelector:@selector(isLaunchProhibited)]) launchProhibited |= proxy.launchProhibited;
    NSBundle *bundle = [NSBundle bundleWithURL:proxy.bundleURL];
    if (!bundle) return NO;
    return CHVisibleApplicationMetadataAllowsPrivilege(identifier, proxy.bundleURL.path,
        [bundle objectForInfoDictionaryKey:@"SBAppTags"], proxyTags, recordTags, launchProhibited);
}

BOOL CHInjectionEnabled(NSDictionary *prefs, NSString *identifier, NSString *executablePath)
{
    id domain = prefs[identifier.length ? kChoicyPrefsKeyAppSettings : kChoicyPrefsKeyDaemonSettings];
    NSString *key = identifier.length ? identifier : executablePath.lastPathComponent;
    id settings = [domain isKindOfClass:NSDictionary.class] && key ? domain[key] : nil;
    id value = [settings isKindOfClass:NSDictionary.class] ? settings[kChoicyProcessPrefsKeyTweakInjectionEnabled] : nil;
    BOOL valid = [value isKindOfClass:NSNumber.class] &&
        ([value isEqual:@YES] || [value isEqual:@NO]);
    if (CHInjectionIsForced(identifier, executablePath)) return YES;
    if (valid) return [value boolValue];
    return CHIsJailbreakApp(identifier, executablePath);
}

BOOL parseNumberBool(id number, BOOL default_)
{
	if (!number) return default_;
	if (![number isKindOfClass:[NSNumber class]]) return default_;

	NSNumber *numberNum = number;
	return numberNum.boolValue;
}

NSInteger parseNumberInteger(id number, NSInteger default_)
{
	if (!number) return default_;
	if (![number isKindOfClass:[NSNumber class]]) return default_;

	NSNumber *numberNum = number;
	return numberNum.integerValue;
}

NSString *localize(NSString *key)
{	
	static NSBundle *CHBundle;
	static NSDictionary *englishLocalizations;

	if (key == nil) {
		return nil;
	}

	if (!CHBundle) {
		CHBundle = [NSBundle bundleWithPath:jbroot(@"/Library/Application Support/ChoicyWhitelist.bundle")];
	}

	NSString *localizedString = [CHBundle localizedStringForKey:key value:key table:nil];

	if ([localizedString isEqualToString:key]) {
		if (!englishLocalizations) {
			englishLocalizations = [NSDictionary dictionaryWithContentsOfFile:[CHBundle pathForResource:@"Localizable" ofType:@"strings" inDirectory:@"en.lproj"]];
		}

		 
		NSString *engString = [englishLocalizations objectForKey:key];

		if (engString) {
			return engString;
		}
		else {
			 
			return key;
		}
	}

	return localizedString;
}

NSDictionary *processPreferencesForApplication(NSDictionary *preferences, NSString *applicationID)
{
	NSDictionary *appSettings = [preferences objectForKey:kChoicyPrefsKeyAppSettings];
	return [appSettings objectForKey:applicationID];
}

NSDictionary *processPreferencesForDaemon(NSDictionary *preferences, NSString *daemonDisplayName)
{
	NSDictionary *daemonSettings = [preferences objectForKey:kChoicyPrefsKeyDaemonSettings];
	return [daemonSettings objectForKey:daemonDisplayName];
}
