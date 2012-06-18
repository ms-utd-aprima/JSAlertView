//
//  EMRAlertView.m
//  Clara
//
//  Created by Jared Sinclair on 3/21/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "JSAlertView.h"
#import "JSAlertViewPresenter.h"
#import <QuartzCore/QuartzCore.h>

// Usage example:
// input image: http://f.cl.ly/items/3v0S3w2B3N0p3e0I082d/Image%202011.07.22%2011:29:25%20PM.png
//
// UIImage *buttonImage = [UIImage ipMaskedImageNamed:@"UIButtonBarAction.png" color:[UIColor redColor]];

// .h
@interface UIImage (IPImageUtils)
+ (UIImage *)ipMaskedImageNamed:(NSString *)name color:(UIColor *)color;
@end

// .m
@implementation UIImage (IPImageUtils)

+ (UIImage *)ipMaskedImageNamed:(NSString *)name color:(UIColor *)color
{
	UIImage *image = [UIImage imageNamed:name];
	CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
	UIGraphicsBeginImageContextWithOptions(rect.size, NO, image.scale);
	CGContextRef c = UIGraphicsGetCurrentContext();
	[image drawInRect:rect];
	CGContextSetFillColorWithColor(c, [color CGColor]);
	CGContextSetBlendMode(c, kCGBlendModeSourceAtop);
	CGContextFillRect(c, rect);
	UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
	return result;
}

@end

@interface JSAlertView ()

@property (weak, nonatomic) JSAlertViewPresenter *presenter;
@property (strong, nonatomic) UIImageView *bgShadow;
@property (strong, nonatomic) UIImageView *littleWindowBG;
@property (strong, nonatomic) UILabel *titleLabel;
@property (strong, nonatomic) UILabel *messageLabel;
@property (strong, nonatomic) UIButton *cancelButton;
@property (strong, nonatomic) NSMutableArray *acceptButtons;
@property (strong, nonatomic) NSString *titleText;
@property (strong, nonatomic) NSString *messageText;
@property (strong, nonatomic) NSString *cancelButtonTitle;
@property (strong, nonatomic) NSMutableArray *acceptButtonTitles;
@property (assign, nonatomic) CGSize messageSize;
@property (assign, nonatomic) CGSize titleSize;
@property (assign, nonatomic) BOOL isBeingDismissed;

- (void)initialSetup;
- (void)cancelButtonPressed:(id)sender;
- (void)actionButtonPressed:(id)sender;
- (void)prepareBackgroundImage;
- (void)prepareTitle;
- (void)prepareMessage;
- (void)prepareCancelButton;
- (void)prepareAcceptButtons;
- (UIImage *)defaultBackgroundImage;

@end

@implementation JSAlertView

@synthesize delegate = _delegate;
@synthesize presenter = _presenter;
@synthesize bgShadow = _bgShadow;
@synthesize littleWindowBG = _littleWindowBG;
@synthesize titleLabel = _titleLabel;
@synthesize messageLabel = _messageLabel;
@synthesize cancelButton = _cancelButton;
@synthesize acceptButtons = _acceptButtons;
@synthesize titleText = _titleText;
@synthesize messageText = _messageText;
@synthesize cancelButtonTitle = _cancelButtonTitle;
@synthesize acceptButtonTitles = _acceptButtonTitles;
@synthesize messageSize = _messageSize;
@synthesize titleSize = _titleSize;
@synthesize numberOfButtons;
@synthesize isBeingDismissed = _isBeingDismissed;
@synthesize tintColor = _tintColor;
@synthesize cancelButtonDismissalStyle = _cancelButtonDismissalStyle;
@synthesize acceptButtonDismissalStyle = _acceptButtonDismissalStyle;

#define kMaxViewWidth 284.0f

#define kDefaultTitleFontSize 18
#define kTitleOriginX 20
#define kTitleLeadingTop 19
#define kTitleLeadingBottom 10
#define kTitleSpacingMultiplier 1.5
#define kMaxTitleWidth 244
#define kMaxTitleNumberOfLines 3

#define kDefaultMessageFontSize 16
#define kMaxMessageWidth 256.0f
#define kMaxMessageNumberOfLines 8
#define kMessageOriginX 14

#define kSpacing 7
#define kSpaceAboveTopButton 7
#define kSpaceAfterOneOfSeveralActionButtons 6
#define kSpaceAboveSeparatedCancelButton 7
#define kSpaceAfterBottomButton 15

#define kLeftButtonOriginX 11
#define kRightButtonOriginX 146
#define kMinButtonWidth 127
#define kMaxButtonWidth 262
#define kButtonHeight 44.0f

#define kWidthForDefaultAlphaBG 268

- (id)initWithTitle:(NSString *)title message:(NSString *)message delegate:(id /*<JSAlertViewDelegate>*/)delegate cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ... {
    self = [super init];
    if (self) {
        [self initialSetup];
        _titleText = title && title.length > 0 ? title : @"Untitled Alert";
        _cancelButtonTitle = cancelButtonTitle;
        _acceptButtonTitles = [NSMutableArray array];
        va_list args;
        va_start(args, otherButtonTitles);
        for (NSString *arg = otherButtonTitles; arg != nil; arg = va_arg(args, NSString*)) {
            if (arg.length > 0) {
                [_acceptButtonTitles addObject:arg];
            }
        }
        va_end(args);
        _acceptButtons = [NSMutableArray array];
        _messageText = message;
    }    
    return self;
}

- (int)numberOfButtons {
    int count = 0;
    if (_cancelButton) {
        count += 1;
    }
    count += _acceptButtons.count;
    return count;
}

- (void)show {
    [self prepareBackgroundImage];
    [self prepareTitle];
    if (_messageText && _messageText.length > 0) {
        [self prepareMessage];
    } else {
        _messageSize = CGSizeZero;
    }
    if (_cancelButtonTitle && _cancelButtonTitle.length > 0) {
        [self prepareCancelButton];
    }
    [self prepareAcceptButtons];
    CGFloat height = kTitleLeadingTop + _titleSize.height + kTitleLeadingBottom ;
    if (_messageLabel) {
        height += _messageSize.height + kSpacing;
    }
    height += kSpaceAboveTopButton;
    if (_cancelButton) {
        height += kButtonHeight + kSpaceAfterBottomButton;
        if (_acceptButtons.count > 1) {
            height += (kButtonHeight + kSpaceAfterOneOfSeveralActionButtons) * _acceptButtonTitles.count + kSpaceAboveSeparatedCancelButton + kSpacing;
        }
    } else {
        height += (kButtonHeight + kSpaceAfterOneOfSeveralActionButtons) * _acceptButtonTitles.count - kSpaceAfterOneOfSeveralActionButtons + kSpaceAfterBottomButton;
    } 
    self.frame = CGRectMake(0, 0, kMaxViewWidth, height);
    /*UIImageView *dropShadow = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"alertView_dropShadow.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(62, 62, 62, 62)]];
    dropShadow.frame = CGRectMake(-24.0f, -24.0f, kMaxViewWidth + 48, height + 48);
    [self insertSubview:dropShadow atIndex:0];*/
    [_presenter showAlertView:self];
}

- (void)dismissWithTappedButtonIndex:(NSInteger)index animated:(BOOL)animated {
    if (_isBeingDismissed == NO) {
        _isBeingDismissed = YES;
        [_presenter JS_alertView:self tappedButtonAtIndex:index animated:animated];
    }
}

- (void)cancelButtonPressed:(id)sender {
    if ([self.delegate respondsToSelector:@selector(JS_alertView:tappedButtonAtIndex:)]) {
        [self.delegate JS_alertView:self tappedButtonAtIndex:kCancelButtonIndex];
    }
    if (_isBeingDismissed == NO) {
        _isBeingDismissed = YES;
        [_presenter JS_alertView:self tappedButtonAtIndex:kCancelButtonIndex animated:YES];
    }
}

- (void)actionButtonPressed:(id)sender {
    UIButton *acceptButton = (UIButton *)sender;
    if ([self.delegate respondsToSelector:@selector(JS_alertView:tappedButtonAtIndex:)]) {
        [self.delegate JS_alertView:self tappedButtonAtIndex:acceptButton.tag];
    }
    [_presenter JS_alertView:self tappedButtonAtIndex:acceptButton.tag animated:YES];
}

#pragma mark - Convenience

- (void)initialSetup {
    _presenter = [JSAlertViewPresenter sharedAlertViewPresenter];
    self.frame = CGRectMake(0, 0, kMaxViewWidth, kMaxViewWidth);
    self.backgroundColor = [UIColor clearColor];
}

- (void)prepareBackgroundImage {
    self.littleWindowBG = [[UIImageView alloc] initWithImage:[self defaultBackgroundImage]];
    _littleWindowBG.frame = self.frame;
    _littleWindowBG.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _littleWindowBG.userInteractionEnabled = YES;
    UIImageView *overlayBorder = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"jsAlertView_defaultBackground_overlay.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(40, 40, 40, 40)]];
    overlayBorder.frame = _littleWindowBG.frame;
    overlayBorder.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlayBorder.userInteractionEnabled = NO;
    [self addSubview:_littleWindowBG];
    [self addSubview:overlayBorder];
}

- (void)prepareTitle {
    self.titleLabel = [[UILabel alloc] init];
    self.titleSize = [_titleText sizeWithFont:[UIFont boldSystemFontOfSize:kDefaultTitleFontSize] 
                            constrainedToSize:CGSizeMake(kMaxTitleWidth, kDefaultTitleFontSize * kMaxTitleNumberOfLines) 
                                lineBreakMode:UILineBreakModeTailTruncation];
    _titleLabel.frame = CGRectMake(kTitleOriginX, kTitleLeadingTop, kMaxTitleWidth, _titleSize.height);
    _titleLabel.textAlignment = UITextAlignmentCenter;
    _titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
    _titleLabel.font = [UIFont boldSystemFontOfSize:kDefaultTitleFontSize];
    _titleLabel.text = _titleText;
    _titleLabel.numberOfLines = kMaxTitleNumberOfLines;
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
    [_littleWindowBG addSubview:_titleLabel];
}

- (void)prepareMessage {
    self.messageLabel = [[UILabel alloc] init];
    self.messageSize = [_messageText sizeWithFont:[UIFont boldSystemFontOfSize:kDefaultMessageFontSize] 
                            constrainedToSize:CGSizeMake(kMaxMessageWidth, kMaxMessageNumberOfLines * kDefaultMessageFontSize) 
                                lineBreakMode:UILineBreakModeTailTruncation];
    _messageLabel.frame = CGRectMake(kMessageOriginX, kTitleLeadingTop + _titleSize.height + kTitleLeadingBottom, kMaxMessageWidth, _messageSize.height);
    _messageLabel.textAlignment = UITextAlignmentCenter;
    _messageLabel.lineBreakMode = UILineBreakModeTailTruncation;
    _messageLabel.textColor = [UIColor whiteColor];
    _messageLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
    _messageLabel.font = [UIFont systemFontOfSize:kDefaultMessageFontSize];
    _messageLabel.text = _messageText;
    _messageLabel.numberOfLines = kMaxMessageNumberOfLines;
    _messageLabel.backgroundColor = [UIColor clearColor];
    _messageLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
    [_littleWindowBG addSubview:_messageLabel];
}

- (void)prepareCancelButton {
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat yOrigin = kTitleLeadingTop + _titleSize.height + kTitleLeadingBottom;
    if (_messageLabel) {
        yOrigin += _messageSize.height + kSpacing;
    }
    yOrigin += kSpaceAboveTopButton;
    if (_acceptButtonTitles.count > 1) {
        yOrigin += (kButtonHeight + kSpaceAfterOneOfSeveralActionButtons) * _acceptButtonTitles.count + kSpacing + kSpaceAboveSeparatedCancelButton;
        _cancelButton.frame = CGRectMake(kLeftButtonOriginX, yOrigin, kMaxButtonWidth, kButtonHeight);
    } else if (_acceptButtonTitles.count == 1) {
        _cancelButton.frame = CGRectMake(kLeftButtonOriginX, yOrigin, kMinButtonWidth, kButtonHeight);
    } else {
        _cancelButton.frame = CGRectMake(kLeftButtonOriginX, yOrigin, kMaxButtonWidth, kButtonHeight);
    }
    if (_acceptButtonTitles.count > 0) {
        [_cancelButton setBackgroundImage:[[UIImage imageNamed:@"jsAlertView_iOS_cancelButton_normal.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 20, 0, 20)]
                                 forState:UIControlStateNormal];
    } else {
        [_cancelButton setBackgroundImage:[[UIImage imageNamed:@"jsAlertView_iOS_okayButton_normal.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 20, 0, 20)]
                                forState:UIControlStateNormal];
    }
    [_cancelButton setBackgroundImage:[[UIImage imageNamed:@"jsAlertView_iOS_okayCancelButton_highlighted.png"]  resizableImageWithCapInsets:UIEdgeInsetsMake(0, 20, 0, 20)]
                             forState:UIControlStateHighlighted];
    [_cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_cancelButton setTitleShadowColor:[UIColor colorWithWhite:0.0f alpha:0.5f] forState:UIControlStateNormal];
    [_cancelButton setTitle:_cancelButtonTitle forState:UIControlStateNormal];
    _cancelButton.titleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
    [_cancelButton addTarget:self action:@selector(cancelButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    _cancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:kDefaultTitleFontSize];
    [_littleWindowBG addSubview:_cancelButton];
}

- (void)prepareAcceptButtons {
    for (int index = 0; index < _acceptButtonTitles.count; index++) {
        NSString *buttonTitle = [_acceptButtonTitles objectAtIndex:index];
        UIButton *acceptButton = [UIButton buttonWithType:UIButtonTypeCustom];
        CGFloat yOrigin = kTitleLeadingTop + _titleSize.height + kTitleLeadingBottom;
        if (_messageLabel) {
            yOrigin += _messageSize.height + kSpacing;
        }
        yOrigin += kSpaceAboveTopButton;
        if (_acceptButtonTitles.count > 1) {
            yOrigin += (kButtonHeight + kSpaceAfterOneOfSeveralActionButtons) * index;
            acceptButton.frame = CGRectMake(kLeftButtonOriginX, yOrigin, kMaxButtonWidth, kButtonHeight);
        } else if (_cancelButtonTitle) {
            acceptButton.frame = CGRectMake(kRightButtonOriginX, yOrigin, kMinButtonWidth, kButtonHeight);
        } else {
            acceptButton.frame = CGRectMake(kLeftButtonOriginX, yOrigin, kMaxButtonWidth, kButtonHeight);
        }
        [acceptButton setBackgroundImage:[[UIImage imageNamed:@"jsAlertView_iOS_okayButton_normal.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 20, 0, 20)]
                                 forState:UIControlStateNormal];
        [acceptButton setBackgroundImage:[[UIImage imageNamed:@"jsAlertView_iOS_okayCancelButton_highlighted.png"]  resizableImageWithCapInsets:UIEdgeInsetsMake(0, 20, 0, 20)]
                                 forState:UIControlStateHighlighted];
        [acceptButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [acceptButton setTitleShadowColor:[UIColor colorWithWhite:0.0f alpha:0.5f] forState:UIControlStateNormal];
        [acceptButton setTitle:buttonTitle forState:UIControlStateNormal];
        acceptButton.titleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
        [acceptButton addTarget:self action:@selector(actionButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        acceptButton.titleLabel.font = [UIFont boldSystemFontOfSize:kDefaultTitleFontSize];
        [_littleWindowBG addSubview:acceptButton];
        acceptButton.tag = index + 1;
        [_acceptButtons addObject:acceptButton];
    }
}

- (UIImage *)defaultBackgroundImage {
    UIEdgeInsets _defaultBackgroundEdgeInsets = UIEdgeInsetsMake(40, 40, 40, 40);
    if (self.tintColor == nil) {
        self.tintColor = [[JSAlertViewPresenter sharedAlertViewPresenter] defaultColor];
    }
    UIImage *defaultImageWithColor = [UIImage ipMaskedImageNamed:@"jsAlertView_defaultBackground_alphaOnly.png" color:self.tintColor];
    UIImage *_defaultBackgroundImage = [defaultImageWithColor resizableImageWithCapInsets:_defaultBackgroundEdgeInsets];
    return _defaultBackgroundImage;
}

+ (void)setDefaultAcceptButtonDismissalAnimationStyle:(JSAlertViewDismissalStyle)style {
    [[JSAlertViewPresenter sharedAlertViewPresenter] setDefaultAcceptDismissalStyle:style];
}

+ (void)setDefaultCancelButtonDismissalAnimationStyle:(JSAlertViewDismissalStyle)style {
    [[JSAlertViewPresenter sharedAlertViewPresenter] setDefaultCancelDismissalStyle:style];
}

+ (void)setDefaultTintColor:(UIColor *)tint {
    [[JSAlertViewPresenter sharedAlertViewPresenter] setDefaultColor:tint];
}

+ (void)resetDefaults {
    [[JSAlertViewPresenter sharedAlertViewPresenter] resetDefaultAppearance];
}

@end










