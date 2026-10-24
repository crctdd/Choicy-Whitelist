#import <Preferences/PSTableCell.h>
#import <Preferences/PSSpecifier.h>
#import <QuartzCore/QuartzCore.h>
@interface CHWLPluginCell : PSTableCell
@property (nonatomic) UIScrollView *pluginScrollView;
@property (nonatomic) UILabel *pluginLabel;
@end
@implementation CHWLPluginCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier specifier:specifier];
    if (self) [self refreshCellContentsWithSpecifier:specifier];
    return self;
}
- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier
{
    [super refreshCellContentsWithSpecifier:specifier];
    self.userInteractionEnabled = YES;
    self.contentView.userInteractionEnabled = YES;
    if (!self.pluginScrollView) {
        UIScrollView *view = [UIScrollView new];
        view.scrollEnabled = YES;
        view.alwaysBounceVertical = YES;
        view.showsVerticalScrollIndicator = YES;
        view.directionalLockEnabled = YES;
        view.delaysContentTouches = NO;
        view.canCancelContentTouches = YES;
        view.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        view.backgroundColor = UIColor.tertiarySystemFillColor;
        view.layer.cornerRadius = 10;
        view.clipsToBounds = YES;
        UILabel *label = [UILabel new];
        label.font = [UIFont systemFontOfSize:15];
        label.textColor = UIColor.labelColor;
        label.numberOfLines = 0;
        label.userInteractionEnabled = NO;
        [view addSubview:label];
        [self.contentView addSubview:view];
        self.pluginScrollView = view;
        self.pluginLabel = label;
    }
    NSString *text = [specifier propertyForKey:@"chwlBoxText"] ?: @"";
    if (![self.pluginLabel.text isEqualToString:text]) {
        self.pluginLabel.text = text;
        self.pluginScrollView.contentOffset = CGPointZero;
    }
    self.textLabel.hidden = YES;
    self.detailTextLabel.hidden = YES;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    [self setNeedsLayout];
}
- (void)setValue:(id)value { }
- (void)setUserInteractionEnabled:(BOOL)enabled
{
                                                                                        
    [super setUserInteractionEnabled:YES];
}
- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.contentView.bounds;
    self.contentView.userInteractionEnabled = YES;
    self.pluginScrollView.frame = CGRectMake(12, 8, MAX(0, bounds.size.width - 24), MAX(0, bounds.size.height - 16));
    CGFloat width = MAX(0, self.pluginScrollView.bounds.size.width - 24);
    CGSize textSize = [self.pluginLabel sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    self.pluginLabel.frame = CGRectMake(12, 12, width, ceil(textSize.height));
    self.pluginScrollView.contentSize = CGSizeMake(self.pluginScrollView.bounds.size.width, ceil(textSize.height) + 24);
}
@end
