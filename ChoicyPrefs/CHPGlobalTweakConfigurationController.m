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

#import "CHPGlobalTweakConfigurationController.h"
#import "CHPTweakList.h"
#import "CHPTweakInfo.h"
#import "CHPRootListController.h"
#import "CHPPackageInfo.h"
#import "../Shared.h"
#import "CHPPreferences.h"
#import "../ChoicyPrefsMigrator.h"

@implementation CHPGlobalTweakConfigurationController

- (NSString *)topTitle
{
	return localize(@"GLOBAL_TWEAK_CONFIGURATION");
}

- (NSString *)plistName
{
	return @"GlobalTweakConfiguration";
}

- (void)viewDidLoad
{
	[self applySearchControllerHideWhileScrolling:YES];
	[super viewDidLoad];
}

- (NSMutableArray *)specifiers
{
	if (!_specifiers) {
		_specifiers = [super specifiers];

		[self loadGlobalTweakBlacklist];

		PSSpecifier *groupSpecifier = [PSSpecifier emptyGroupSpecifier];
		groupSpecifier.name = localize(@"TWEAKS");
		[groupSpecifier setProperty:localize(@"GLOBAL_TWEAK_CONFIGURATION_BOTTOM_NOTICE") forKey:@"footerText"];

		[_specifiers addObject:groupSpecifier];

		CHPTweakList *sharedTweakList = [CHPTweakList sharedInstance];

		__block BOOL atLeastOneTweakDisabled = NO;

		[sharedTweakList.tweakList enumerateObjectsUsingBlock:^(CHPTweakInfo *tweakInfo, NSUInteger idx, BOOL *stop) {
			if ([sharedTweakList isTweakHiddenForAnyProcess:tweakInfo]) return;

			if (_searchKey && ![_searchKey isEqualToString:@""]) {
				if (![tweakInfo.dylibName localizedStandardContainsString:_searchKey]) {
					return;
				}
			}

			PSSpecifier *tweakSpecifier = [PSSpecifier preferenceSpecifierNamed:tweakInfo.dylibName
						  target:self
						  set:@selector(setPreferenceValue:forTweakWithSpecifier:)
						  get:@selector(readValueForTweakWithSpecifier:)
						  detail:nil
						  cell:PSSwitchCell
						  edit:nil];

			BOOL enabled = ![dylibsBeforeChoicy containsObject:tweakInfo.dylibName];
			if (!enabled) {
				atLeastOneTweakDisabled = YES;
			}
			
			[tweakSpecifier setProperty:NSClassFromString(@"CHPSubtitleSwitch") forKey:@"cellClass"];
			[tweakSpecifier setProperty:@(enabled) forKey:@"enabled"];
			[tweakSpecifier setProperty:tweakInfo.dylibName forKey:@"key"];
			[tweakSpecifier setProperty:@YES forKey:@"default"];
			[tweakSpecifier setProperty:@YES forKey:@"chwlInspectBundleTargets"];
			NSMutableArray<NSString *> *bundleIdentifiers = [NSMutableArray new];
			if ([tweakInfo.explicitFilterBundles isKindOfClass:NSArray.class]) {
				for (id identifier in tweakInfo.explicitFilterBundles) {
					if ([identifier isKindOfClass:NSString.class] && [identifier length]) {
						[bundleIdentifiers addObject:identifier];
					}
				}
			}
			[tweakSpecifier setProperty:bundleIdentifiers.copy forKey:@"chwlPlistBundleIdentifiers"];
			NSMutableArray<NSString *> *executables = [NSMutableArray new];
			if ([tweakInfo.filterExecutables isKindOfClass:NSArray.class]) {
				for (id executable in tweakInfo.filterExecutables) {
					if ([executable isKindOfClass:NSString.class] && [executable length]) {
						[executables addObject:executable];
					}
				}
			}
			[tweakSpecifier setProperty:executables.copy forKey:@"chwlPlistExecutables"];

			CHPPackageInfo *packageInfo = [CHPPackageInfo fetchPackageInfoForDylibName:tweakInfo.dylibName];
			if (packageInfo) {
				[tweakSpecifier setProperty:[NSString stringWithFormat:@"%@: %@", localize(@"PACKAGE"), packageInfo.name] forKey:@"subtitle"];
			}

			[_specifiers addObject:tweakSpecifier];
		}];

		if (atLeastOneTweakDisabled) {
			PSSpecifier *greyedOutInfoSpecifier = [PSSpecifier preferenceSpecifierNamed:localize(@"GREYED_OUT_ENTRIES")
						  target:self
						  set:nil
						  get:nil
						  detail:nil
						  cell:PSButtonCell
						  edit:nil];
			
			[greyedOutInfoSpecifier setProperty:@YES forKey:@"enabled"];
			greyedOutInfoSpecifier.buttonAction = @selector(presentNotLoadingFirstWarning);
			[_specifiers addObject:greyedOutInfoSpecifier];
		}
	}

	return _specifiers;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
	if ([[specifier propertyForKey:@"chwlInspectBundleTargets"] boolValue]) {
		cell.selectionStyle = UITableViewCellSelectionStyleDefault;
		cell.userInteractionEnabled = YES;
	}
	return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
	if ([[specifier propertyForKey:@"chwlInspectBundleTargets"] boolValue]) return indexPath;
	return [super tableView:tableView willSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
	if ([[specifier propertyForKey:@"chwlInspectBundleTargets"] boolValue]) {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		[self presentBundleTargetsForSpecifier:specifier];
		return;
	}
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)presentBundleTargetsForSpecifier:(PSSpecifier *)specifier
{
	if (self.presentedViewController && self.presentedViewController != _searchController) return;
	NSArray<NSString *> *identifiers = [specifier propertyForKey:@"chwlPlistBundleIdentifiers"];
	NSArray<NSString *> *executables = [specifier propertyForKey:@"chwlPlistExecutables"];
	NSMutableArray<NSString *> *sections = [NSMutableArray new];
	if (identifiers.count) {
		[sections addObject:[@"Filter → Bundles\n\n" stringByAppendingString:[identifiers componentsJoinedByString:@"\n"]]];
	}
	if (executables.count) {
		[sections addObject:[@"Filter → Executables\n\n" stringByAppendingString:[executables componentsJoinedByString:@"\n"]]];
	}
	NSString *targets = sections.count ? [sections componentsJoinedByString:@"\n\n"] : @"未指定 Bundle ID 或进程名";
	NSString *title = [[specifier propertyForKey:@"key"] stringByAppendingPathExtension:@"plist"];
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
		message:targets
		preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleDefault handler:nil]];
	alert.view.tintColor = UIColor.systemBlueColor;
	UIViewController *presenter = self;
	if (_searchController.active && _searchController.presentingViewController) presenter = _searchController;
	[presenter presentViewController:alert animated:YES completion:nil];
}

- (void)presentNotLoadingFirstWarning
{
	presentNotLoadingFirstWarning(self, NO);
}

- (void)setPreferenceValue:(id)value forTweakWithSpecifier:(PSSpecifier *)specifier
{
	NSNumber *numberValue = value;

	if (numberValue.boolValue) {
		[_globalDeniedTweaks removeObject:[specifier propertyForKey:@"key"]];
	}
	else {
		[_globalDeniedTweaks addObject:[specifier propertyForKey:@"key"]];
	}

	[self saveGlobalTweakBlacklist];
}

- (id)readValueForTweakWithSpecifier:(PSSpecifier *)specifier
{
	NSString *key = [specifier propertyForKey:@"key"];

	if ([dylibsBeforeChoicy containsObject:key]) {
		return @1;
	}

	if ([_globalDeniedTweaks containsObject:key]) {
		return @0;
	}
	else {
		return @1;
	}
}

- (void)loadGlobalTweakBlacklist
{
	_globalDeniedTweaks = [[preferences objectForKey:kChoicyPrefsKeyGlobalDeniedTweaks] mutableCopy] ?: [NSMutableArray new];
}

- (void)saveGlobalTweakBlacklist
{
	NSMutableDictionary *mutablePrefs = preferencesForWriting();
	mutablePrefs[kChoicyPrefsKeyGlobalDeniedTweaks] = [_globalDeniedTweaks copy];
	writePreferences(mutablePrefs);
}

@end
