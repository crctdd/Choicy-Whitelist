#import <Foundation/Foundation.h>
#import <Preferences/PSSpecifier.h>
extern NSString *const CHWLMatchesChanged;
NSString *CHWLDisplayConfigurationSummary(NSString *summary);
void CHWLRefreshMatches(void);
NSArray *CHWLMatchesForSpecifier(PSSpecifier *row);
BOOL CHWLUsesFrameworkMatching(PSSpecifier *row);
BOOL CHWLPrivilegeEligibleForSpecifier(PSSpecifier *row);
void CHWLRequestFrameworkMatchesForSpecifier(PSSpecifier *row);
void CHWLRememberListState(id controller);
BOOL CHWLListStateChanged(id controller);
void CHWLDecorateRow(PSSpecifier *row);
NSMutableArray *CHWLGroupRows(NSArray<PSSpecifier *> *rows, NSString *name);
NSString *CHWLIdentifier(PSSpecifier *row);
NSString *CHWLExecutable(PSSpecifier *row);
