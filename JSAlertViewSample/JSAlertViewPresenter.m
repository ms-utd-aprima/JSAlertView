//
//  JSAlertViewPresenter.m
//  JSAlertViewSample
//
//  Created by Jared Sinclair on 6/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "JSAlertViewPresenter.h"
#import "JSAlertView.h"
#import <QuartzCore/QuartzCore.h>

// https://github.com/TomSwift/TSAlertView/blob/master/TSAlertView/TSAlertView.m

@interface TSAlertOverlayWindow : UIWindow
{
}
@property (nonatomic,retain) UIWindow* oldKeyWindow;
@end

@implementation  TSAlertOverlayWindow
@synthesize oldKeyWindow;

- (void) makeKeyAndVisible
{
	self.oldKeyWindow = [[UIApplication sharedApplication] keyWindow];
	self.windowLevel = UIWindowLevelAlert;
	[super makeKeyAndVisible];
}

- (void) resignKeyWindow
{
	[super resignKeyWindow];
	[self.oldKeyWindow makeKeyWindow];
}

- (void) drawRect: (CGRect) rect
{
	// render the radial gradient behind the alertview
    self.layer.contentsScale = 2.0;
	CGFloat width			= self.frame.size.width;
	CGFloat height			= self.frame.size.height;
	CGFloat locations[3]	= { 0.0, 0.5, 1.0 	};
	CGFloat components[12]	= {	0, 0, 0, 0.1,
		0, 0, 0, 0.33,
		0, 0, 0, 0.5	};
    
	CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
	CGGradientRef backgroundGradient = CGGradientCreateWithColorComponents(colorspace, components, locations, 3);
	CGColorSpaceRelease(colorspace);
    
	CGContextDrawRadialGradient(UIGraphicsGetCurrentContext(), 
								backgroundGradient, 
								CGPointMake(width/2, height/2), 0,
								CGPointMake(width/2, height/2), width,
								0);
    
	CGGradientRelease(backgroundGradient);
}

@end


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

@interface JSAlertViewPresenter ()

@property (nonatomic, strong) NSMutableArray *alertViews;
@property (nonatomic, strong) JSAlertView *visibleAlertView;
@property (nonatomic, strong) UIView *alertContainerView;
@property (nonatomic, assign) UIDeviceOrientation currentOrientation;
@property (nonatomic, strong) UIWindow *alertOverlayWindow;
@property (nonatomic, strong) UIImageView *bgShadow;
@property (nonatomic, assign) BOOL isAnimating;

- (void)dismissAlertView:(JSAlertView *)alertView withCancelAnimation:(BOOL)animated;
- (void)dismissAlertView:(JSAlertView *)alertView withAcceptAnimation:(BOOL)animated;

- (void)dismissAlertView:(JSAlertView *)alertView withShrinkAnimation:(BOOL)animated;
- (void)dismissAlertView:(JSAlertView *)alertView withFallAnimation:(BOOL)animated;
- (void)dismissAlertView:(JSAlertView *)alertView withExpandAnimation:(BOOL)animated;
- (void)dismissAlertView:(JSAlertView *)alertView withFadeAnimation:(BOOL)animated;

- (void)prepareBackgroundShadow;
- (void)prepareAlertContainerView;
- (void)prepareWindow;
- (void)presentAlertView:(JSAlertView *)alertView;
- (void)showNextAlertView;
- (void)hideBackgroundShadow;

@end

@implementation JSAlertViewPresenter

@synthesize defaultBackgroundImage = _defaultBackgroundImage;
@synthesize defaultBackgroundEdgeInsets = _defaultBackgroundEdgeInsets;
@synthesize defaultCancelButtonImage_Normal = _defaultCancelButtonImage_Normal;
@synthesize defaultCancelButtonImage_Highlighted = _defaultCancelButtonImage_Highlighted;
@synthesize defaultAcceptButtonImage_Normal = _defaultAcceptButtonImage_Normal;
@synthesize defaultAcceptButtonImage_Highlighted = _defaultAcceptButtonImage_Highlighted;
@synthesize defaultTitleTextAttributes = _defaultTitleTextAttributes;
@synthesize defaultMessageTextAttributes = _defaultMessageTextAttributes;
@synthesize defaultCancelButtonTextAttributes = _defaultCancelButtonTextAttributes;
@synthesize defaultAcceptButtonTextAttributes = _defaultAcceptButtonTextAttributes;
@synthesize defaultCancelDismissalStyle = _defaultCancelDismissalStyle;
@synthesize defaultAcceptDismissalStyle = _defaultAcceptDismissalStyle;
@synthesize alertViews = _alertViews;
@synthesize visibleAlertView = _visibleAlertView;
@synthesize alertContainerView = _alertContainerView;
@synthesize currentOrientation = _currentOrientation;
@synthesize alertOverlayWindow = _alertOverlayWindow;
@synthesize bgShadow = _bgShadow;
@synthesize isAnimating = _isAnimating;

+ (id)sharedAlertViewPresenter {
    static dispatch_once_t once;
    static JSAlertViewPresenter *sharedAlertViewPresenter;
    dispatch_once(&once, ^ { sharedAlertViewPresenter = [[self alloc] init]; });
    return sharedAlertViewPresenter;
}

- (id)init {
    self = [super init];
    if (self) {
        NSAssert([[[UIApplication sharedApplication] keyWindow] rootViewController], @"JSAlertView requires that your application's keyWindow has a rootViewController");
        _alertViews = [NSMutableArray array];
        [self resetDefaultAppearance];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRotate:) name:UIDeviceOrientationDidChangeNotification object:nil];
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    }
    return self;
}

#pragma mark - Rotation

- (void)didRotate:(NSNotification *)notification {
    UIWindow *mainWindow = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
    UIViewController *rootVC = mainWindow.rootViewController;
    UIViewController *currentViewController = rootVC;
    if (rootVC.presentedViewController) {
        currentViewController = rootVC.presentedViewController;
    }
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    
    if ([currentViewController shouldAutorotateToInterfaceOrientation:orientation] == NO)
        return;
    
    CGFloat duration = 0.3;
    if ( (UIDeviceOrientationIsLandscape(self.currentOrientation) && UIDeviceOrientationIsLandscape(orientation)) 
        || (UIDeviceOrientationIsPortrait(orientation) && UIDeviceOrientationIsPortrait(self.currentOrientation)) ) {
        duration = 0.6;
    }
    self.currentOrientation = orientation;
    [UIView animateWithDuration:duration animations:^{
        switch (orientation) {
            case UIDeviceOrientationPortrait:
                _alertContainerView.transform = CGAffineTransformMakeRotation(0);
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                _alertContainerView.transform = CGAffineTransformMakeRotation(M_PI);
                break;
            case UIDeviceOrientationLandscapeLeft:
                _alertContainerView.transform = CGAffineTransformMakeRotation(M_PI / 2);
                break;
            case UIDeviceOrientationLandscapeRight:
                _alertContainerView.transform = CGAffineTransformMakeRotation(M_PI / -2);
                break; 
            default:
                break;
        }
    }];
}

#pragma mark - Show, Hide, Respond

- (void)showAlertView:(JSAlertView *)alertView {
    [self.alertViews addObject:alertView];
    if (self.visibleAlertView == nil && _isAnimating == NO) {
        [self presentAlertView:alertView];
    }
}

- (void)presentAlertView:(JSAlertView *)alertView {
    _isAnimating = YES;
    self.visibleAlertView = alertView;
    
    if (self.alertOverlayWindow == nil) {
        [self prepareWindow];
    }
    
    if (self.bgShadow == nil) {
        [self prepareBackgroundShadow];
    }
    
    if (self.alertContainerView == nil) {
        [self prepareAlertContainerView];
    }
    
    alertView.transform = CGAffineTransformMakeScale(0.05f, 0.05f);
    alertView.alpha = 0.0f;
    alertView.center = CGPointMake(floorf(_alertContainerView.center.x), floorf(_alertContainerView.center.y));
    [_alertContainerView addSubview:alertView];
    
    [UIView animateWithDuration:0.2f animations:^{
        alertView.alpha = 1.0f;
        _bgShadow.alpha = 1.0f;
    }];
    
    [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        alertView.transform = CGAffineTransformMakeScale(1.05f, 1.05f);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
            alertView.transform = CGAffineTransformMakeScale(0.97f, 0.97f);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.05f delay:0.0f options:UIViewAnimationOptionCurveEaseIn animations:^{
                alertView.transform = CGAffineTransformIdentity;
            } completion:^(BOOL finished) {
                _isAnimating = NO;
            }];
        }];
    }];
}

- (void)showNextAlertView {
    if (self.alertViews.count > 0) {
        [self presentAlertView:[self.alertViews objectAtIndex:0]];
    } 
}

- (void)hideBackgroundShadow {
    [UIView animateWithDuration:0.33f animations:^{
        _bgShadow.alpha = 0.0f;
    } completion:^(BOOL finished) {
        _isAnimating = NO;
        [_bgShadow removeFromSuperview];
        [_alertContainerView removeFromSuperview];
        [_alertOverlayWindow removeFromSuperview];
        self.bgShadow = nil;
        self.alertContainerView = nil;
        self.alertOverlayWindow = nil;
        [(UIWindow *)[[[UIApplication sharedApplication] windows] objectAtIndex:0] makeKeyWindow];
    }];
}

- (void)JS_alertView:(JSAlertView *)sender tappedButtonAtIndex:(NSInteger)index animated:(BOOL)animated {
    if (index == kCancelButtonIndex) {      
        if (sender.numberOfButtons > 1) {
            [self dismissAlertView:sender withCancelAnimation:animated];
        } else {
            [self dismissAlertView:sender withAcceptAnimation:animated];
        }
    } else {
        [self dismissAlertView:sender withAcceptAnimation:animated];
    }
}

- (void)dismissAlertView:(JSAlertView *)alertView withCancelAnimation:(BOOL)animated {
    if (self.alertViews.count == 1) {
        [self hideBackgroundShadow];
    }
    switch (self.defaultCancelDismissalStyle) {
        case JSAlertViewDismissalStyleShrink:
            [self dismissAlertView:alertView withShrinkAnimation:animated];
            break;
        case JSAlertViewDismissalStyleFall:
            [self dismissAlertView:alertView withFallAnimation:animated];
            break;
        case JSAlertViewDismissalStyleExpand:
            [self dismissAlertView:alertView withExpandAnimation:animated];
            break;
        case JSAlertViewDismissalStyleFade:
            [self dismissAlertView:alertView withFadeAnimation:animated];
            break;
        default:
            break;
    }    
}

- (void)dismissAlertView:(JSAlertView *)alertView withAcceptAnimation:(BOOL)animated {
    if (self.alertViews.count == 1) {
        [self hideBackgroundShadow];
    }
    switch (self.defaultAcceptDismissalStyle) {
        case JSAlertViewDismissalStyleShrink:
            [self dismissAlertView:alertView withShrinkAnimation:animated];
            break;
        case JSAlertViewDismissalStyleFall:
            [self dismissAlertView:alertView withFallAnimation:animated];
            break;
        case JSAlertViewDismissalStyleExpand:
            [self dismissAlertView:alertView withExpandAnimation:animated];
            break;
        case JSAlertViewDismissalStyleFade:
            [self dismissAlertView:alertView withFadeAnimation:animated];
            break;
        default:
            break;
    }
}

- (void)dismissAlertView:(JSAlertView *)alertView withShrinkAnimation:(BOOL)animated {
    CGFloat duration = 0.0f;
    if (animated) {
        duration = 0.2f;
    }
    __weak UIView *blockSafeAlertView = alertView;
    [UIView animateWithDuration:duration delay:0.0f options:UIViewAnimationOptionCurveEaseIn animations:^{
        blockSafeAlertView.alpha = 0.0f;
        blockSafeAlertView.transform = CGAffineTransformMakeScale(0.01, 0.01);
    } completion:^(BOOL finished) {
        [blockSafeAlertView removeFromSuperview];
        [self.alertViews removeObject:blockSafeAlertView];
        self.visibleAlertView = nil;
        [self showNextAlertView];
    }];
}

- (void)dismissAlertView:(JSAlertView *)alertView withFallAnimation:(BOOL)animated {
    CGFloat duration = 0.0f;
    if (animated) {
        duration = 0.3f;
    }
    __weak UIView *blockSafeAlertView = alertView;
    [UIView animateWithDuration:duration delay:0.0f options:UIViewAnimationOptionCurveEaseIn animations:^{
        blockSafeAlertView.alpha = 0.0f;
        CGRect frame = blockSafeAlertView.frame;
        frame.origin.y += 320.0f;
        blockSafeAlertView.frame = frame;
        blockSafeAlertView.transform = CGAffineTransformMakeRotation(M_PI / -3.5);
    } completion:^(BOOL finished) {
        [blockSafeAlertView removeFromSuperview];
        [self.alertViews removeObject:blockSafeAlertView];
        self.visibleAlertView = nil;
        [self showNextAlertView];
    }];
}

- (void)dismissAlertView:(JSAlertView *)alertView withExpandAnimation:(BOOL)animated {
    CGFloat duration = 0.0f;
    if (animated) {
        duration = 0.25f;
    }
    __weak UIView *blockSafeAlertView = alertView;
    [UIView animateWithDuration:duration delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
        blockSafeAlertView.alpha = 0.0f;
        blockSafeAlertView.transform = CGAffineTransformMakeScale(1.2, 1.2);
    } completion:^(BOOL finished) {
        [blockSafeAlertView removeFromSuperview];
        [self.alertViews removeObject:blockSafeAlertView];
        self.visibleAlertView = nil;
        [self showNextAlertView];
    }];
}

- (void)dismissAlertView:(JSAlertView *)alertView withFadeAnimation:(BOOL)animated {
    CGFloat duration = 0.0f;
    if (animated) {
        duration = 0.25f;
    }
    [UIView animateWithDuration:duration delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
        alertView.alpha = 0.0f;
    } completion:^(BOOL finished) {
        [alertView removeFromSuperview];
        [self.alertViews removeObject:alertView];
        self.visibleAlertView = nil;
        [self showNextAlertView];
    }];
}

#pragma mark - Convenience Methods

- (void)prepareWindow {
    self.alertOverlayWindow = [[UIWindow alloc] initWithFrame:[[[UIApplication sharedApplication] keyWindow] frame]];
    _alertOverlayWindow.windowLevel = UIWindowLevelAlert;
    _alertOverlayWindow.backgroundColor = [UIColor clearColor];
    [self.alertOverlayWindow makeKeyAndVisible];
}

- (void)prepareBackgroundShadow {
    UIImage *shadowImage;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        shadowImage = [UIImage imageNamed:@"jsAlertView_gradientShadowOverlay_iPhone.png"];
    } else if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        shadowImage = [UIImage imageNamed:@"jsAlertView_gradientShadowOverlay_iPad.png"];
    }
    self.bgShadow = [[UIImageView alloc] initWithImage:shadowImage];
    _bgShadow.frame = [[UIScreen mainScreen] bounds];
    _bgShadow.contentMode = UIViewContentModeScaleToFill;
    _bgShadow.center = _alertOverlayWindow.center;
    _bgShadow.alpha = 0.0f;
    [_alertOverlayWindow addSubview:_bgShadow];
}

- (void)prepareAlertContainerView {
    self.alertContainerView = [[UIView alloc] initWithFrame:_alertOverlayWindow.bounds];
    _alertContainerView.clipsToBounds = NO;
    [_alertOverlayWindow addSubview:_alertContainerView];
    _currentOrientation = [[UIDevice currentDevice] orientation];
    UIViewController *currentViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    if (currentViewController.presentedViewController) {
        currentViewController = currentViewController.presentedViewController;
    }
    if ([currentViewController shouldAutorotateToInterfaceOrientation:_currentOrientation] == NO) {
        if (UIDeviceOrientationIsLandscape(_currentOrientation)) {
            _currentOrientation = _currentOrientation == UIDeviceOrientationLandscapeRight ? UIDeviceOrientationLandscapeRight : UIDeviceOrientationLandscapeLeft;
        } else {
            _currentOrientation = _currentOrientation == UIDeviceOrientationPortrait ? UIDeviceOrientationPortrait : UIDeviceOrientationPortraitUpsideDown;
        }
    }
    switch (_currentOrientation) {
        case UIDeviceOrientationPortrait:
            _alertContainerView.transform = CGAffineTransformMakeRotation(0);
            break;
        case UIDeviceOrientationLandscapeLeft:
            _alertContainerView.transform = CGAffineTransformMakeRotation(M_PI / 2);
            break;
        case UIDeviceOrientationLandscapeRight:
            _alertContainerView.transform = CGAffineTransformMakeRotation(M_PI / -2);
            break; 
        default:
            break;
    }
}

- (void)resetDefaultAppearance {
    _defaultBackgroundEdgeInsets = UIEdgeInsetsMake(40, 40, 40, 40);
    UIImage *defaultWithColor = [UIImage ipMaskedImageNamed:@"jsAlertView_defaultBackground_alphaOnly.png" color:[UIColor colorWithRed:0.3 green:0.0 blue:0.3 alpha:1.0]];
    _defaultBackgroundImage = [defaultWithColor resizableImageWithCapInsets:_defaultBackgroundEdgeInsets];
    _defaultCancelDismissalStyle = JSAlertViewDismissalStyleFade;
    _defaultAcceptDismissalStyle = JSAlertViewDismissalStyleFade;
}

@end










