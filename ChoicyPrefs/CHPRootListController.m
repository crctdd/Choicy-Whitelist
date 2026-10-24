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

#import "CHPRootListController.h"
#import "../Shared.h"
#import "CHPDaemonList.h"
#import "CHPTweakList.h"
#import <mach-o/dyld.h>
#import "CHPPreferences.h"
#import "CHWLListSupport.h"
#import <Preferences/PSTableCell.h>
#import "../ChoicyPrefsMigrator.h"
#import <roothide.h>

NSArray *dylibsBeforeChoicy;

#import <dirent.h>

NSDictionary *preferences;

void choicy_reloadPreferences()
{
	preferences = [NSDictionary dictionaryWithContentsOfFile:kChoicyPrefsPlistPath];
}

NSMutableDictionary *preferencesForWriting()
{
	NSDictionary *latest = [NSDictionary dictionaryWithContentsOfFile:kChoicyPrefsPlistPath];
	if (latest) {
		return latest.mutableCopy;
	}
	else {
		NSMutableDictionary *mutablePrefs = [NSMutableDictionary new];
		[ChoicyPrefsMigrator updatePreferenceVersion:mutablePrefs];
		return mutablePrefs;
	}
}

void writePreferences(NSMutableDictionary *mutablePrefs)
{
	if (!kChoicyPrefsPlistPath) return;
    [[NSFileManager defaultManager] createDirectoryAtPath:kChoicyPrefsPlistPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    if (![mutablePrefs writeToFile:kChoicyPrefsPlistPath atomically:YES]) return;
    preferences = mutablePrefs.copy;
	[CHPListController sendChoicyPrefsPostNotification];
}

NSString *getInjectionPlatform()
{
	static NSString *injectionPlatform = nil;

	if (!injectionPlatform) {
		for (uint32_t i = 0; i < _dyld_image_count(); i++) {
			const char *pathC = _dyld_get_image_name(i);
			NSString *path = [NSString stringWithUTF8String:pathC];

			if ([path hasSuffix:@"/usr/lib/substitute-inserter.dylib"]) {
				injectionPlatform = @"Substitute";
			}
			else if ([path hasSuffix:@"/usr/lib/TweakInject.dylib"]) {
				injectionPlatform = @"libhooker";
			}
			else if ([path hasSuffix:@"/usr/lib/substrate/SubstrateInserter.dylib"]) {
				injectionPlatform = @"Substrate";
			}
		}

		if (!injectionPlatform) {
			injectionPlatform = localize(@"THE_INJECTION_PLATFORM");
		}
	}

	return injectionPlatform;
}

@implementation CHPRootListController

- (NSString *)title
{
	return @"Choicy-Whitelist";
}

- (NSString *)plistName
{
	return @"Root";
}

- (NSMutableArray *)specifiers
{
    NSMutableArray *rows = [super specifiers];
    for (PSSpecifier *row in rows) {
        NSString *symbol = [row propertyForKey:@"chwlSystemImage"];
        if (!symbol.length || [[row propertyForKey:@"chwlSymbolPrepared"] boolValue]) continue;
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithTextStyle:UIFontTextStyleBody
            scale:UIImageSymbolScaleLarge];
        UIImage *glyph = [UIImage systemImageNamed:symbol withConfiguration:configuration];
                                                                                        
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(32, 32)];
        UIImage *icon = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            if (!glyph || glyph.size.width <= 0 || glyph.size.height <= 0) return;
            CGFloat scale = MIN(1, MIN(28 / glyph.size.width, 28 / glyph.size.height));
            CGSize size = CGSizeMake(glyph.size.width * scale, glyph.size.height * scale);
            [glyph drawInRect:CGRectMake((32 - size.width) / 2, (32 - size.height) / 2, size.width, size.height)];
        }];
        [row setProperty:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forKey:@"iconImage"];
        [row setProperty:@YES forKey:@"chwlSymbolPrepared"];
    }
    return rows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PSTableCell *cell = (PSTableCell *)[super tableView:tableView cellForRowAtIndexPath:indexPath];
    cell.imageView.image = [cell.specifier propertyForKey:@"iconImage"];
    cell.imageView.tintColor = UIColor.systemBlueColor;
    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    return cell;
}

- (void)openProjectLink:(PSSpecifier *)specifier
{
    NSURL *url = [NSURL URLWithString:[specifier propertyForKey:@"chwlURL"]];
    if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

- (void)rebuildProcessCache
{
    [[NSFileManager defaultManager] removeItemAtPath:kChoicyProcessCachePath error:nil];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"CACHE_REMOVED_TITLE")
        message:localize(@"CACHE_REMOVED_MESSAGE") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)resetPreferences
{
	UIAlertController *resetPreferencesAlert = [UIAlertController alertControllerWithTitle:localize(@"RESET_PREFERENCES") message:localize(@"RESET_PREFERENCES_MESSAGE") preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *continueAction = [UIAlertAction actionWithTitle:localize(@"CONTINUE") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
		[[NSFileManager defaultManager] removeItemAtPath:kChoicyPrefsPlistPath error:nil];
		[[self class] sendChoicyPrefsPostNotification];
	}];

	UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:localize(@"CANCEL") style:UIAlertActionStyleDefault handler:nil];
	
	[resetPreferencesAlert addAction:continueAction];
	[resetPreferencesAlert addAction:cancelAction];

	[self presentViewController:resetPreferencesAlert animated:YES completion:nil];
}

void presentNotLoadingFirstWarning(PSListController *plc, BOOL showDontShowAgainOption)
{
	PSSpecifier *dontShowAgainSpecifier = [PSSpecifier preferenceSpecifierNamed:@"dontShowWarningAgain"
					target:plc
					set:nil
					get:nil
					detail:nil
					cell:0
					edit:nil];

	[dontShowAgainSpecifier setProperty:@"com.crctdd.choicy-whitelist" forKey:@"defaults"];
	[dontShowAgainSpecifier setProperty:@"dontShowWarningAgain" forKey:@"key"];
	[dontShowAgainSpecifier setProperty:@"com.crctdd.choicy-whitelist/ReloadPrefs" forKey:@"PostNotification"];

	NSNumber *dontShowAgainNum = nil;
	if (showDontShowAgainOption) {
		dontShowAgainNum = [plc readPreferenceValue:dontShowAgainSpecifier];
	}

	if (![dontShowAgainNum boolValue]) {
		NSString *injectionPlatform = getInjectionPlatform();

		NSString *message = [NSString stringWithFormat:localize(@"TWEAKS_LOADING_BEFORE_CHOICY_ALERT_MESSAGE"), injectionPlatform];

		if ([injectionPlatform isEqualToString:@"Substrate"]) {
			message = [message stringByAppendingString:[@" " stringByAppendingString:localize(@"CHOICYLOADER_ADVICE")]];
		}

		UIAlertController *warningAlert = [UIAlertController alertControllerWithTitle:localize(@"WARNING_ALERT_TITLE") message:message preferredStyle:UIAlertControllerStyleAlert];
	
		if ([injectionPlatform isEqualToString:@"Substrate"]) {
			UIAlertAction *openRepoAction = [UIAlertAction actionWithTitle:localize(@"OPEN_REPO") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
				[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://opa334.github.io"]];
			}];

			[warningAlert addAction:openRepoAction];
		}

		if (showDontShowAgainOption) {
			UIAlertAction *dontShowAgainAction = [UIAlertAction actionWithTitle:localize(@"DONT_SHOW_AGAIN") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
				[plc setPreferenceValue:@1 specifier:dontShowAgainSpecifier];
			}];

			[warningAlert addAction:dontShowAgainAction];
		}

		UIAlertAction *closeAction = [UIAlertAction actionWithTitle:localize(@"CLOSE") style:UIAlertActionStyleDefault handler:nil];

		[warningAlert addAction:closeAction];

		if ([warningAlert respondsToSelector:@selector(setPreferredAction:)]) {
			warningAlert.preferredAction = closeAction;
		}

		[plc presentViewController:warningAlert animated:YES completion:nil];
	}
}

- (void)viewDidLoad
{
	[super viewDidLoad];
    UIAction *respringAction = [UIAction actionWithTitle:localize(@"RESPRING") image:nil identifier:nil handler:^(__kindof UIAction *action) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
            CFSTR("com.crctdd.choicy-whitelist/respring"), NULL, NULL, YES);
    }];
    UIAction *restartAction = [UIAction actionWithTitle:localize(@"RESTART_SPRINGBOARD") image:nil identifier:nil handler:^(__kindof UIAction *action) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
            CFSTR("com.crctdd.choicy-whitelist/restartSpringBoard"), NULL, NULL, YES);
    }];
    UIMenu *menu = [UIMenu menuWithTitle:@"" children:@[respringAction, restartAction]];
    UIBarButtonItem *actionsButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"]
        menu:menu];
    actionsButton.tintColor = UIColor.systemBlueColor;
    actionsButton.accessibilityLabel = localize(@"MORE_ACTIONS");
    self.navigationItem.rightBarButtonItem = actionsButton;
    CHWLRefreshMatches();
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [[CHPDaemonList sharedInstance] prepareApplicationExtensionsIfNeeded];
        [[CHPDaemonList sharedInstance] updateDaemonListIfNeeded];
    });

	if (dylibsBeforeChoicy) {
		presentNotLoadingFirstWarning(self, YES);
	}
}

@end

void determineLoadingOrder()
{
	NSMutableArray *dylibsInOrder = [NSMutableArray new];
	NSString *injectionLibrariesPath = [CHPTweakList injectionLibrariesPath];

	BOOL isSubstrate = [getInjectionPlatform() isEqualToString:@"Substrate"];
	if (isSubstrate) {
		                                                                                     
		DIR *dir;
		struct dirent *dp;
		dir = opendir(injectionLibrariesPath.UTF8String);
		dp=readdir(dir);    
		dp=readdir(dir);     
		while ((dp = readdir(dir)) != NULL) {
			NSString *filename = [NSString stringWithCString:dp->d_name encoding:NSUTF8StringEncoding];

			if ([filename.pathExtension isEqualToString:@"dylib"]) {
				[dylibsInOrder addObject:[filename stringByDeletingPathExtension]];
			}
		}
	}
	else {
		                                                        
		NSMutableArray *contents = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:injectionLibrariesPath error:nil] mutableCopy];
		NSArray *plists = [contents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF ENDSWITH %@", @"plist"]];
		for (NSString *plist in plists) {
			NSString *dylibName = [plist stringByDeletingPathExtension];
			[dylibsInOrder addObject:dylibName];
		}
		[dylibsInOrder sortUsingSelector:@selector(caseInsensitiveCompare:)];
	}

	NSUInteger choicyIndex = [dylibsInOrder indexOfObject:kChoicyDylibName];

	if (choicyIndex == NSNotFound) return;

	if (choicyIndex != 0) {
		dylibsBeforeChoicy = [dylibsInOrder subarrayWithRange:NSMakeRange(0,choicyIndex)];
	}

	if (dylibsBeforeChoicy && isSubstrate) {
		NSDictionary *targetLoaderAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:jbroot(@"/usr/lib/substrate/SubstrateLoader.dylib") error:nil];

		if ([[targetLoaderAttributes objectForKey:NSFileType] isEqualToString:NSFileTypeSymbolicLink]) {
			NSString *destination = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath:jbroot(@"/usr/lib/substrate/SubstrateLoader.dylib") error:nil];
			if ([destination hasPrefix:@"/usr/lib/ChoicyLoader.dylib"]) {
				                                                                       
				dylibsBeforeChoicy = nil;
			}
		}
	}

	if(access(jbroot("/usr/lib/ellekit/libinjector.dylib"), F_OK)==0) {
		dylibsBeforeChoicy = nil;
	}
}

__attribute__((constructor))
static void init(void)
{
	choicy_reloadPreferences();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)choicy_reloadPreferences, CFSTR("com.crctdd.choicy-whitelist/ReloadPrefs"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	determineLoadingOrder();
}
