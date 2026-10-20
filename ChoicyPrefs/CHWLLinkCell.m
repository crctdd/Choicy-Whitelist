#import <Preferences/PSTableCell.h>
#import <Preferences/PSSpecifier.h>

@interface CHWLLinkCell : PSTableCell
@end

@implementation CHWLLinkCell
- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier
{
    [super refreshCellContentsWithSpecifier:specifier];
    self.textLabel.textColor = UIColor.systemBlueColor;
}
- (void)layoutSubviews
{
    [super layoutSubviews];
    self.textLabel.textColor = UIColor.systemBlueColor;
}
@end
