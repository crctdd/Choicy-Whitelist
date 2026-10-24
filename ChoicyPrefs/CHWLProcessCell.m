#import "../Shared.h"
#import <Preferences/PSTableCell.h>
#import <Preferences/PSSpecifier.h>

@interface CHWLProcessCell : PSTableCell
@property (nonatomic) UILabel *injectionLabel;
@property (nonatomic) UILabel *thirdPartyLabel;
@property (nonatomic) UILabel *configurationLabel;
@end

@implementation CHWLProcessCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier
{
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier specifier:specifier];
    if (self) {
        _thirdPartyLabel = [UILabel new];
        _thirdPartyLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _thirdPartyLabel.adjustsFontForContentSizeCategory = YES;
        _thirdPartyLabel.numberOfLines = 1;
        _thirdPartyLabel.textColor = UIColor.systemOrangeColor;
        [self.contentView addSubview:_thirdPartyLabel];
        _injectionLabel = [UILabel new];
        _injectionLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _injectionLabel.adjustsFontForContentSizeCategory = YES;
        _injectionLabel.numberOfLines = 1;
        [self.contentView addSubview:_injectionLabel];
        _configurationLabel = [UILabel new];
        _configurationLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _configurationLabel.textColor = UIColor.secondaryLabelColor;
        _configurationLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_configurationLabel];
        [self refreshCellContentsWithSpecifier:specifier];
    }
    return self;
}
- (void)setValue:(id)value { }
- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier
{
    [super refreshCellContentsWithSpecifier:specifier];
    self.textLabel.text = specifier.name;
    self.textLabel.textColor = UIColor.labelColor;
    self.detailTextLabel.text = [specifier propertyForKey:@"chwlIdentifier"];
    self.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    BOOL matched = [[specifier propertyForKey:@"chwlMatched"] boolValue];
    BOOL enabled = [[specifier propertyForKey:@"chwlInjectionEnabled"] boolValue];
    BOOL thirdParty = [[specifier propertyForKey:@"chwlThirdPartyProcess"] boolValue];
    self.detailTextLabel.textColor = enabled ?
        (thirdParty ? UIColor.systemOrangeColor : UIColor.systemGreenColor) : UIColor.secondaryLabelColor;
    self.thirdPartyLabel.text = !enabled && thirdParty ? localize(@"THIRD_PARTY_PROCESS") : nil;
    self.thirdPartyLabel.hidden = enabled || !thirdParty;
    self.injectionLabel.text = !enabled && matched ? localize(@"EXPLICIT_INJECTION_PENDING") : nil;
    self.injectionLabel.hidden = enabled || !matched;
    self.injectionLabel.textColor = UIColor.systemRedColor;
    self.configurationLabel.text = [specifier propertyForKey:@"chwlConfigurationSummary"];
    self.configurationLabel.hidden = !self.configurationLabel.text.length;
    self.accessibilityLabel = [@[specifier.name ?: @"", self.detailTextLabel.text ?: @"", self.thirdPartyLabel.text ?: @"",
        self.injectionLabel.text ?: @"", self.configurationLabel.text ?: @""] componentsJoinedByString:@", "];
    [self setNeedsLayout];
}
- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat x = MAX(self.textLabel.frame.origin.x, 16);
    CGFloat width = MAX(0, self.contentView.bounds.size.width - x - 16);
    CGFloat statusWidth = self.configurationLabel.hidden ? 0 : MIN(ceil(self.configurationLabel.intrinsicContentSize.width), width * 0.6);
    self.configurationLabel.frame = CGRectMake(x + width - statusWidth,
        floor((self.contentView.bounds.size.height - 18) / 2), statusWidth, 18);
    self.textLabel.frame = CGRectMake(x, 7, MAX(0, width - statusWidth - (statusWidth > 0 ? 8 : 0)), 22);
    self.detailTextLabel.frame = CGRectMake(x, 30, width, 16);
    self.thirdPartyLabel.frame = CGRectMake(x, 49, width, 16);
    self.injectionLabel.frame = CGRectMake(x, self.thirdPartyLabel.hidden ? 49 : 68, width, 16);
}
@end
