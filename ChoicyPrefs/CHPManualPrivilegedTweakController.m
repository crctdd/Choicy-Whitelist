#import "../Shared.h"
#import "CHPManualPrivilegedTweakController.h"
#import "CHPPreferences.h"
#import "CHPTweakList.h"
#import "CHPTweakInfo.h"
#import "CHPPackageInfo.h"
#import "CHWLData.h"
#import "CHWLListSupport.h"

@interface CHPManualPrivilegedTweakController ()
@property (nonatomic) NSMutableSet<NSString *> *selectedNames;
@property (nonatomic) NSSet<NSString *> *initialNames;
@end

@implementation CHPManualPrivilegedTweakController

- (NSString *)topTitle { return localize(@"MANAGE_PRIVILEGED_TWEAKS"); }
- (NSString *)plistName { return nil; }

- (void)prepareSelectionIfNeeded
{
    if (self.selectedNames) return;
    extern void choicy_reloadPreferences(void);
    choicy_reloadPreferences();
    self.initialNames = [NSSet setWithArray:CHWLManualPrivilegedTweakNames(preferences)];
    self.selectedNames = self.initialNames.mutableCopy;
}

- (void)viewDidLoad
{
    [self prepareSelectionIfNeeded];
    [self applySearchControllerHideWhileScrolling:NO];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(matchesChanged:)
        name:CHWLMatchesChanged object:nil];
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:localize(@"SAVE")
        style:UIBarButtonItemStyleDone target:self action:@selector(saveSelection)];
    self.navigationItem.rightBarButtonItem.tintColor = UIColor.systemBlueColor;
}

- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }

- (void)viewWillAppear:(BOOL)animated
{
    [self prepareSelectionIfNeeded];
    [super viewWillAppear:animated];
    CHWLRefreshMatches();
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (!self.parentViewController) {
        self.selectedNames = nil;
        self.initialNames = nil;
        _specifiers = nil;
    }
}

- (void)matchesChanged:(NSNotification *)notification
{
    (void)notification;
    if (self.isViewLoaded && self.view.window) [self reloadSpecifiers];
    else _specifiers = nil;
}

- (NSMutableArray *)specifiers
{
    [self prepareSelectionIfNeeded];
    [super specifiers];
    if (!_specifiers) {
        _specifiers = [NSMutableArray arrayWithObject:[PSSpecifier emptyGroupSpecifier]];
        CHPTweakList *list = CHPTweakList.sharedInstance;
        for (CHPTweakInfo *tweak in list.tweakList) {
            if (tweak.isUIKitTweak || [list isTweakHiddenForAnyProcess:tweak]) continue;
            CHPPackageInfo *package = [CHPPackageInfo fetchPackageInfoForDylibName:tweak.dylibName];
            if (_searchKey.length && ![tweak.dylibName localizedStandardContainsString:_searchKey] &&
                ![package.name localizedStandardContainsString:_searchKey]) continue;
            PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:tweak.dylibName target:self
                set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
            [row setProperty:tweak.dylibName forKey:@"chwlManualTweak"];
            [row setProperty:@YES forKey:@"enabled"];
            [_specifiers addObject:row];
        }
        if (_specifiers.count == 1) {
            [_specifiers addObject:[PSSpecifier preferenceSpecifierNamed:
                (_searchKey.length ? localize(@"NO_MATCHING_TWEAKS") : localize(@"NO_ADDABLE_TWEAKS")) target:self
                set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil]];
        }
    }
    return _specifiers;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    NSString *name = [[self specifierAtIndexPath:indexPath] propertyForKey:@"chwlManualTweak"];
    cell.accessoryType = name && [self.selectedNames containsObject:name] ?
        UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.tintColor = UIColor.systemBlueColor;
    cell.selectionStyle = name ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    cell.userInteractionEnabled = name != nil;
    if (name) {
        cell.textLabel.enabled = YES;
        cell.textLabel.textColor = UIColor.labelColor;
    }
    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [[self specifierAtIndexPath:indexPath] propertyForKey:@"chwlManualTweak"] ? indexPath : nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *name = [[self specifierAtIndexPath:indexPath] propertyForKey:@"chwlManualTweak"];
    if (!name) return;
    if ([self.selectedNames containsObject:name]) [self.selectedNames removeObject:name];
    else [self.selectedNames addObject:name];
    [tableView cellForRowAtIndexPath:indexPath].accessoryType = [self.selectedNames containsObject:name] ?
        UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)saveSelection
{
    NSMutableDictionary *latest = preferencesForWriting();
    CHPTweakList *list = CHPTweakList.sharedInstance;
    NSMutableSet *installed = [NSMutableSet new], *selected = [NSMutableSet new];
    for (CHPTweakInfo *tweak in list.tweakList) {
        [installed addObject:tweak.dylibName];
        if (!tweak.isUIKitTweak && ![list isTweakHiddenForAnyProcess:tweak] &&
            [self.selectedNames containsObject:tweak.dylibName]) [selected addObject:tweak.dylibName];
    }
    for (NSString *name in self.initialNames) {
        if (![installed containsObject:name] && [self.selectedNames containsObject:name]) [selected addObject:name];
    }
    writePreferences([CHWLPreferencesBySettingManualPrivileges(latest, selected.allObjects) mutableCopy]);
    [self.navigationController popViewControllerAnimated:YES];
}
@end
