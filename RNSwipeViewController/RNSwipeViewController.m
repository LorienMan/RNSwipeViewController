/*
 * RNSwipeViewController
 *
 * Created by Ryan Nystrom on 10/2/12.
 * Copyright (c) 2012 Ryan Nystrom. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "RNSwipeViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "RNDirectionPanGestureRecognizer.h"
#import "UIView+Sizes.h"
#import "UIApplication+AppDimensions.h"
#import "RNSwipeViewControllerProtocol.h"

NSString * const RNSwipeViewControllerLeftWillAppear = @"com.whoisryannystrom.RNSwipeViewControllerLeftWillAppear";
NSString * const RNSwipeViewControllerLeftDidAppear = @"com.whoisryannystrom.RNSwipeViewControllerLeftDidAppear";
NSString * const RNSwipeViewControllerRightWillAppear = @"com.whoisryannystrom.RNSwipeViewControllerRightWillAppear";
NSString * const RNSwipeViewControllerRightDidAppear = @"com.whoisryannystrom.RNSwipeViewControllerRightDidAppear";
NSString * const RNSwipeViewControllerCenterWillAppear = @"com.whoisryannystrom.RNSwipeViewControllerCenterWillAppear";
NSString * const RNSwipeViewControllerCenterDidAppear = @"com.whoisryannystrom.RNSwipeViewControllerCenterDidAppear";

static CGFloat kRNSwipeDefaultDuration = 0.2f;
static CGFloat kRNSwipeMinVelocityToForceShow = 300.f;
static CGFloat kRNSwipeInertiaWidth = 10.f;
static CGFloat kRNSwipeInertiaDuration = 0.15f;

@interface RNSwipeViewController ()

@property (assign, nonatomic, readwrite) BOOL isToggled;
@property (assign, nonatomic) RNDirection activeDirection;

@end

@implementation RNSwipeViewController {
    UIView *_centerContainer;
    UIView *_leftContainer;
    UIView *_rightContainer;
    
    UIImageView *_leftShadowImageView;
    UIImageView *_rightShadowImageView;
    
    UIView *_activeContainer;
    
    RNDirectionPanGestureRecognizer *_panGesture;
    
    UITapGestureRecognizer *_tapGesture;
    
    CGRect _centerOriginal;
    
    CGPoint _centerLastPoint;

    UIView *overlayView;
    BOOL nowDragging;
    BOOL nowAnimating;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self _init];
    }
    return self;
}

- (id)init {
    if (self = [super init]) {
        [self _init];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self _init];
    }
    return self;
}

// initial vars
- (void)_init {
    _visibleState = RNSwipeVisibleCenter;
    
    _leftVisibleWidth = 200.f;
    _rightVisibleWidth = 200.f;
    
    _activeContainer = nil;
    
    _centerOriginal = CGRectZero;
    
    _canShowLeft = YES;
    _canShowRight = YES;

    _bounces = YES;
    _swipeEnabled = YES;
}

#pragma mark - Viewcontroller

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _centerContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    _centerContainer.clipsToBounds = NO;
    _centerContainer.layer.masksToBounds = NO;
    [self _loadCenter];
    
    _centerOriginal = _centerContainer.frame;
    
    _rightContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    [self _loadRight];

    _leftContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    [self _loadLeft];

    _centerLastPoint = CGPointZero;
    
    [self _layoutCenterContainer];
    [self _layoutRightContainer];
    [self _layoutLeftContainer];
    
    [self.view addSubview:_rightContainer];
    [self.view addSubview:_leftContainer];
    [self.view addSubview:_centerContainer];
    
    self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    
    _panGesture = [[RNDirectionPanGestureRecognizer alloc] initWithTarget:self action:@selector(_handlePan:)];
    _panGesture.minimumNumberOfTouches = 1;
    _panGesture.maximumNumberOfTouches = 1;
    _panGesture.delegate = self;
    [self.view addGestureRecognizer:_panGesture];

    overlayView = [UIView new];
    overlayView.backgroundColor = [UIColor clearColor];
    _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(centerViewWasTapped:)];
    _tapGesture.numberOfTapsRequired = 1;
    [overlayView addGestureRecognizer:_tapGesture];
    
    _leftShadowImageView = [[UIImageView alloc] initWithImage:_leftShadowImage];
    _leftShadowImageView.contentMode = UIViewContentModeScaleToFill;
    [_centerContainer addSubview:_leftShadowImageView];
    
    _rightShadowImageView = [[UIImageView alloc] initWithImage:_rightShadowImage];
    _rightShadowImageView.contentMode = UIViewContentModeScaleToFill;
    [_centerContainer addSubview:_rightShadowImageView];
    
    [self _layoutContainersAnimated:NO duration:0.f];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
        
    [self _layoutShadowImageViews];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self setController:self.visibleController active:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    [self setController:self.visibleController active:NO];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self _resizeForOrienation:toInterfaceOrientation];
}

- (BOOL)onScreen {
    return self.isViewLoaded && self.view.window;
}

#pragma mark - Public methods

- (void)showLeft {
    [self showLeftWithRemainingDurationAndInertia:NO];
}

- (void)showLeftWithDuration:(NSTimeInterval)duration {
    [self showLeftWithDuration:duration inertia:NO];
}

- (void)showLeftWithRemainingDurationAndInertia:(BOOL)inertia {
    CGFloat duration = [self _remainingDuration:abs(_centerContainer.left - self.leftVisibleWidth) threshold:self.leftVisibleWidth];
    [self showLeftWithDuration:duration inertia:inertia];
}

- (void)showLeftWithDuration:(NSTimeInterval)duration inertia:(BOOL)inertia {
    [self _placeContainerBehindCenterContainer:_leftContainer];
    if (self.leftViewController) {
        [self.centerViewController viewWillDisappear:YES];
        [self.leftViewController viewWillAppear:YES];
        [self _sendCenterToPoint:CGPointMake(self.leftVisibleWidth, 0) duration:duration inertia:inertia completion:^{
            [self.centerViewController viewDidDisappear:YES];
            [self.leftViewController viewDidAppear:YES];
        }];
        self.visibleState = RNSwipeVisibleLeft;
    }
}

- (void)showRight {
    [self showRightWithRemainingDurationAndInertia:NO];
}

- (void)showRightWithDuration:(NSTimeInterval)duration {
    [self showRightWithDuration:duration inertia:NO];
}

- (void)showRightWithRemainingDurationAndInertia:(BOOL)inertia {
    CGFloat duration = [self _remainingDuration:abs(self.rightVisibleWidth + _centerContainer.left) threshold:self.rightVisibleWidth];
    [self showRightWithDuration:duration inertia:inertia];
}

- (void)showRightWithDuration:(NSTimeInterval)duration inertia:(BOOL)inertia {
    [self _placeContainerBehindCenterContainer:_rightContainer];
    if (self.rightViewController) {
        [self.centerViewController viewWillDisappear:YES];
        [self.rightViewController viewWillAppear:YES];
        [self _sendCenterToPoint:CGPointMake(-1 * self.rightVisibleWidth, 0) duration:duration inertia:inertia completion:^{
            [self.centerViewController viewDidDisappear:YES];
            [self.rightViewController viewDidAppear:YES];
        }];
        self.visibleState = RNSwipeVisibleRight;
    }
}

- (void)showCenterWithDuration:(NSTimeInterval)duration inertia:(BOOL)inertia {
    [self.visibleController viewWillDisappear:YES];
    [self.centerViewController viewWillAppear:YES];
    [self _sendCenterToPoint:CGPointZero duration:duration inertia:inertia completion:^{
        [self.visibleController viewDidDisappear:YES];
        [self.centerViewController viewDidAppear:YES];
    }];
    self.visibleState = RNSwipeVisibleCenter;
}

- (void)resetView {
    [self _layoutContainersAnimated:YES duration:kRNSwipeDefaultDuration];
}

#pragma mark - Layout

- (void)_layoutCenterContainer {    
    _centerOriginal = _centerContainer.bounds;
    _centerOriginal.origin = CGPointZero;
}

- (void)_layoutRightContainer {
    self.rightViewController.view.frame = self.view.bounds;
}

- (void)_layoutLeftContainer {
    self.leftViewController.view.frame = self.view.bounds;
}

- (void)_layoutShadowImageViews {
    _leftShadowImageView.frame = CGRectMake(- _leftShadowImage.size.width, 0, _leftShadowImage.size.width, _centerContainer.size.height);
    _rightShadowImageView.frame = CGRectMake(_centerContainer.size.width, 0, _leftShadowImage.size.width, _centerContainer.size.height);
}

#pragma mark - Setters

- (void)setCenterViewController:(UIViewController <RNSwipeViewControllerProtocol> *)centerViewController {
    if (_centerViewController != centerViewController) {
        [_centerViewController.view removeFromSuperview];
        _centerViewController = centerViewController;

        if (_centerViewController)
            [self addChildViewController:_centerViewController];
        
        [self _loadCenter];

        if (self.visibleState == RNSwipeVisibleCenter) {
            [self setController:_centerViewController active:YES];
            [self setController:centerViewController active:NO];
        }
    }
}

- (void)setRightViewController:(UIViewController <RNSwipeViewControllerProtocol> *)rightViewController {
    if (_rightViewController != rightViewController) {
        [_rightViewController.view removeFromSuperview];
        rightViewController.view.frame = _rightContainer.bounds;
        _rightViewController = rightViewController;

        if (_rightViewController)
            [self addChildViewController:_rightViewController];
        
        [self _loadRight];

        if (self.visibleState == RNSwipeVisibleRight) {
            [self setController:_rightViewController active:YES];
            [self setController:rightViewController active:NO];
        }
    }
}

- (void)setLeftViewController:(UIViewController <RNSwipeViewControllerProtocol> *)leftViewController {
    if (_leftViewController != leftViewController) {
        [_leftViewController.view removeFromSuperview];
        leftViewController.view.frame = _leftContainer.bounds;
        _leftViewController = leftViewController;

        if (_leftViewController)
            [self addChildViewController:_leftViewController];
        
        [self _loadLeft];

        if (self.visibleState == RNSwipeVisibleLeft) {
            [self setController:_leftViewController active:YES];
            [self setController:leftViewController active:NO];
        }
    }
}

- (void)setVisibleState:(RNSwipeVisible)visibleState {
    if (_visibleState == visibleState)
        return;

    if (visibleState == RNSwipeVisibleCenter) {
        [overlayView removeFromSuperview];
    } else {
        [self.view addSubview:overlayView];
        overlayView.frame = _centerContainer.frame;
    }

    UIViewController <RNSwipeViewControllerProtocol> *old = self.visibleController;
    _visibleState = visibleState;
    UIViewController <RNSwipeViewControllerProtocol> *new = self.visibleController;

    if (self.onScreen) {
        [self setController:old active:NO];
        [self setController:new active:YES];
    }
}

- (void)setIsToggled:(BOOL)isToggled {
    _isToggled = isToggled;
}

- (void)setLeftVisibleWidth:(CGFloat)leftVisibleWidth {
    if (_leftVisibleWidth != leftVisibleWidth) {
        _leftVisibleWidth = leftVisibleWidth;
        [self _layoutLeftContainer];
        [self _layoutContainersAnimated:NO duration:0.f];
    }
}

- (void)setRightVisibleWidth:(CGFloat)rightVisibleWidth {
    if (_rightVisibleWidth != rightVisibleWidth) {
        _rightVisibleWidth = rightVisibleWidth;
        [self _layoutRightContainer];
        [self _layoutContainersAnimated:NO duration:0.f];
    }
}

- (void)setController:(UIViewController <RNSwipeViewControllerProtocol> *)controller active:(BOOL)active {
    if (!active && controller.active) {
        controller.active = NO;
        if ([controller respondsToSelector:@selector(controllerBecameInactiveInContainer)])
            [controller controllerBecameInactiveInContainer];
    } else if (active && !controller.active) {
        controller.active = YES;
        if ([controller respondsToSelector:@selector(controllerBecameActiveInContainer)])
            [controller controllerBecameActiveInContainer];
    }
}

- (void)setLeftShadowImage:(UIImage *)leftShadowImage {
    _leftShadowImage = leftShadowImage;
    _leftShadowImageView.image = _leftShadowImage;
}

- (void)setRightShadowImage:(UIImage *)rightShadowImage {
    _rightShadowImage = rightShadowImage;
    _rightShadowImageView.image = _rightShadowImage;
}

- (void)setActiveDirection:(RNDirection)activeDirection {
    if (_activeDirection == activeDirection)
        return;
        
    _activeDirection = activeDirection;
    
    if (_activeDirection == RNDirectionLeft && self.visibleState == RNSwipeVisibleCenter) {
        [[NSNotificationCenter defaultCenter] postNotificationName:RNSwipeViewControllerLeftWillAppear object:nil];
        
        if (self.swipeDelegate && [self.swipeDelegate respondsToSelector:@selector(swipeController:willShowController:)]) {
            [self.swipeDelegate swipeController:self willShowController:self.leftViewController];
        }
    }
    else if (_activeDirection == RNDirectionRight && self.visibleState == RNSwipeVisibleCenter) {
        [[NSNotificationCenter defaultCenter] postNotificationName:RNSwipeViewControllerRightWillAppear object:nil];
        
        if (self.swipeDelegate && [self.swipeDelegate respondsToSelector:@selector(swipeController:willShowController:)]) {
            [self.swipeDelegate swipeController:self willShowController:self.rightViewController];
        }
    }
}

#pragma mark - Getters

- (UIViewController*)visibleController {
    if (self.visibleState == RNSwipeVisibleLeft) return self.leftViewController;
    if (self.visibleState == RNSwipeVisibleRight) return self.rightViewController;
    return self.centerViewController;
}

- (BOOL)canShowLeft {
    if (! self.leftViewController) {
        return NO;
    }
    return _canShowLeft;
}

- (BOOL)canShowRight {
    if (! self.rightViewController) {
        return NO;
    }
    return _canShowRight;
}

#pragma mark - Private Helpers

- (void)_resizeForOrienation:(UIInterfaceOrientation)orientation {
    CGSize sizeOriented = [UIApplication sizeInOrientation:orientation];
    
    CGRect centerFrame = _centerContainer.frame;
    centerFrame.size = sizeOriented;
    _centerContainer.frame = centerFrame;
    centerFrame.origin = CGPointZero;
    self.centerViewController.view.frame = centerFrame;
    [_centerContainer layoutSubviews];
    
    [self _layoutCenterContainer];
    
    self.view.frame = centerFrame;
    
    if (self.leftViewController) {
        CGRect leftFrame = _leftContainer.frame;
        leftFrame.size.height = sizeOriented.height;
        leftFrame.size.width = self.leftVisibleWidth;
        _leftContainer.frame = leftFrame;
        leftFrame.origin = CGPointZero;
        self.leftViewController.view.frame = leftFrame;
        [_leftContainer layoutSubviews];
        
        [self _layoutLeftContainer];
    }
    
    if (self.rightViewController) {
        CGRect rightFrame = _rightContainer.frame;
        rightFrame.size.height = sizeOriented.height;
        rightFrame.size.width = self.rightVisibleWidth;
        _rightContainer.frame = rightFrame;
        rightFrame.origin = CGPointZero;
        self.rightViewController.view.frame = rightFrame;
        [_rightContainer layoutSubviews];
        
        [self _layoutRightContainer];
    }
    
    [self resetView];
}

- (void)_layoutContainersAnimated:(BOOL)animate duration:(NSTimeInterval)duration {
    [[NSNotificationCenter defaultCenter] postNotificationName:RNSwipeViewControllerCenterWillAppear object:nil];
    if (self.swipeDelegate && [self.swipeDelegate respondsToSelector:@selector(swipeController:willShowController:)]) {
        [self.swipeDelegate swipeController:self willShowController:self.centerViewController];
    }
    
    [self.centerViewController viewWillAppear:animate];
    
    void (^block)(void) = ^{
        nowAnimating = YES;
        _centerContainer.frame = _centerOriginal;
    };

    self.visibleState = RNSwipeVisibleCenter;

    if (animate) {
        [UIView animateWithDuration:duration
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:block
                         completion:^(BOOL finished){
                             nowAnimating = NO;
                             _centerLastPoint = CGPointZero;
                             if (finished) {
                                 self.isToggled = NO;
                                 
                                 [self.centerViewController viewDidAppear:animate];

                                 _activeContainer = _centerContainer;
                                 
                                 [[NSNotificationCenter defaultCenter] postNotificationName:RNSwipeViewControllerCenterDidAppear object:nil];
                                 if (self.swipeDelegate && [self.swipeDelegate respondsToSelector:@selector(swipeController:didShowController:)]) {
                                     [self.swipeDelegate swipeController:self didShowController:self.centerViewController];
                                 }
                             }
                         }];
    }
    else {
        block();
        nowAnimating = NO;
    }
    
}

- (void)_placeContainerBehindCenterContainer:(UIView *)container {
    _rightContainer.hidden = container != _rightContainer;
    _leftContainer.hidden = container != _leftContainer;
}

#pragma mark - Adding Views

- (void)_loadCenter {
    if (self.centerViewController && ! self.centerViewController.view.superview && _centerContainer) {
        self.centerViewController.view.frame = _centerContainer.bounds;
        [_centerContainer addSubview:self.centerViewController.view];
    }
}

- (void)_loadLeft {
    if (self.leftViewController && ! self.leftViewController.view.superview && _leftContainer) {
        self.leftViewController.view.frame = _leftContainer.bounds;
        [_leftContainer addSubview:self.leftViewController.view];
    }
}

- (void)_loadRight {
    if (self.rightViewController && ! self.rightViewController.view.superview && _rightContainer) {
        self.rightViewController.view.frame = _rightContainer.bounds;
        [_rightContainer addSubview:self.rightViewController.view];
    }
}

#pragma mark - Animations

- (CGFloat)_remainingDuration:(CGFloat)position threshold:(CGFloat)threshold {
    CGFloat maxDuration = kRNSwipeDefaultDuration;
    threshold /= 2.f;
    CGFloat suggestedDuration = maxDuration * (position / (CGFloat)threshold);
    if (suggestedDuration < 0.05f) {
        return 0.05f;
    }
    if (suggestedDuration < maxDuration) {
        return suggestedDuration;
    }
    return maxDuration;
}

- (CGFloat)_filterLeft:(CGFloat)translation {
    CGFloat newLocation = translation + _centerLastPoint.x;
    CGFloat leftWidth = self.leftVisibleWidth;
    CGFloat rightWidth = (self.visibleState == RNSwipeVisibleCenter || self.visibleState == RNSwipeVisibleRight) ? self.rightVisibleWidth : 0;
    newLocation = newLocation >= leftWidth ? leftWidth + (_bounces ? (newLocation - leftWidth) / 10.f : 0) : newLocation;
    newLocation = newLocation <= -1 * rightWidth ? -1 * rightWidth + (_bounces ? (newLocation + rightWidth) / 10.f : 0) : newLocation;
    newLocation = !self.canShowRight && newLocation <= 0 ? 0 : newLocation;
    newLocation = !self.canShowLeft && newLocation >= 0 ? 0 : newLocation;
    return newLocation;
}

- (CGFloat)_filterRight:(CGFloat)translation {
    CGFloat newLocation = translation + _centerLastPoint.x;
    CGFloat leftWidth = (self.visibleState == RNSwipeVisibleCenter || self.visibleState == RNSwipeVisibleLeft) ? self.leftVisibleWidth : 0;
    CGFloat rightWidth = self.rightVisibleWidth;
    newLocation = newLocation >= leftWidth ? leftWidth + (_bounces ? (newLocation - leftWidth) / 10.f : 0) : newLocation;
    newLocation = newLocation <= -1 * rightWidth ? -1 * rightWidth + (_bounces ? (newLocation + rightWidth) / 10.f : 0) : newLocation;
    newLocation = !self.canShowRight && newLocation <= 0 ? 0 : newLocation;
    newLocation = !self.canShowLeft && newLocation >= 0 ? 0 : newLocation;
    return newLocation;
}

- (void)_sendCenterToPoint:(CGPoint)centerPoint duration:(NSTimeInterval)duration inertia:(BOOL)inertia completion:(void (^)())completionBlock {
    void (^completion)(BOOL) = ^(BOOL finished){
        nowAnimating = NO;
        _centerLastPoint = _centerContainer.origin;
        if (finished) {
            _activeContainer.layer.shouldRasterize = NO;
            self.isToggled = YES;
            
            [self.visibleController viewDidAppear:YES];
            [self.centerViewController viewDidDisappear:YES];
            
            NSString *notificationKey = nil;
            UIViewController *controller = nil;
            if (_activeContainer == _centerContainer) {
                notificationKey = RNSwipeViewControllerCenterDidAppear;
                controller = self.centerViewController;
            }
            else if (_activeContainer == _leftContainer) {
                notificationKey = RNSwipeViewControllerLeftDidAppear;
                controller = self.rightViewController;
            }
            else if (_activeContainer == _rightContainer) {
                notificationKey = RNSwipeViewControllerRightDidAppear;
                controller = self.rightViewController;
            }
            if (notificationKey) {
                [[NSNotificationCenter defaultCenter] postNotificationName:notificationKey object:nil];
            }
            if (controller &&
                self.swipeDelegate &&
                [self.swipeDelegate respondsToSelector:@selector(swipeController:didShowController:)]) {
                [self.swipeDelegate swipeController:self didShowController:controller];
            }
        }
        
        if (completionBlock)
            completionBlock();
    };
    
    CGPoint centerDestination = centerPoint;
    if (inertia) {
        if (_centerContainer.origin.x != centerPoint.x) {
            centerDestination.x += (_centerContainer.origin.x - centerPoint.x < 0) ? kRNSwipeInertiaWidth : - kRNSwipeInertiaWidth;
        }
        if (_centerContainer.origin.y != centerPoint.y) {
            centerDestination.y += (_centerContainer.origin.y - centerPoint.y < 0) ? kRNSwipeInertiaWidth : - kRNSwipeInertiaWidth;
        }
    }
    
    [UIView animateWithDuration:duration
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         nowAnimating = YES;
                         _centerContainer.origin = centerDestination;
                     }
                     completion:^(BOOL finished){
                         if (inertia) {
                             [UIView animateWithDuration:kRNSwipeInertiaDuration
                                                   delay:0
                                                 options:UIViewAnimationOptionBeginFromCurrentState
                                              animations:^{
                                                  nowAnimating = YES;
                                                  _centerContainer.origin = centerPoint;
                                              }
                                              completion:completion];
                         } else {
                             completion(finished);
                         }
                     }];
}

- (void)fastOpenWithVelocity:(CGFloat)velocity {
    RNDirection direction = velocity > 0 ? RNDirectionRight : RNDirectionLeft;
    switch (direction) {
        case RNDirectionLeft:
            if (self.visibleState == RNSwipeVisibleCenter) {
                [self showRightWithDuration:(self.leftVisibleWidth + _centerContainer.left) / velocity inertia:YES];
            } else if (self.visibleState == RNSwipeVisibleLeft) {
                [self showCenterWithDuration:_centerContainer.left / velocity inertia:YES];
            }
            break;
            
        case RNDirectionRight:
            if (self.visibleState == RNSwipeVisibleCenter) {
                [self showLeftWithDuration:(self.leftVisibleWidth - _centerContainer.left) / velocity inertia:YES];
            } else if (self.visibleState == RNSwipeVisibleRight) {
                [self showCenterWithDuration: - _centerContainer.left / velocity inertia:YES];
            }
            break;
    }
}


#pragma mark - Gesture delegate

- (BOOL)gestureRecognizerShouldBegin:(RNDirectionPanGestureRecognizer *)gestureRecognizer {
    BOOL shouldBegin = _swipeEnabled && !nowAnimating;
    
    CGFloat gorizontalVelocity = [gestureRecognizer velocityInView:gestureRecognizer.view].x;
    if (shouldBegin && self.easyOpening && abs(gorizontalVelocity) > kRNSwipeMinVelocityToForceShow) {
        [self fastOpenWithVelocity:gorizontalVelocity];
        shouldBegin = NO;
    }
    
    return shouldBegin;
}

#pragma mark - Gesture handler

- (void)_handlePan:(RNDirectionPanGestureRecognizer*)recognizer {
    // beginning a pan gesture
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        nowDragging = YES;
        [self setController:self.visibleController active:NO];

        self.activeDirection = recognizer.direction;
    }
    
    // changing a pan gesture
    if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGPoint translate = [recognizer translationInView:_centerContainer];
        
        self.activeDirection = recognizer.direction;
        
        CGFloat left = recognizer.direction == RNDirectionLeft ? [self _filterLeft:translate.x] : [self _filterRight:translate.x];
        _centerContainer.left = left;
        
        if (recognizer.direction == RNDirectionLeft && self.visibleState != RNSwipeVisibleLeft) {
            [self _placeContainerBehindCenterContainer:_rightContainer];
        }
        if (recognizer.direction == RNDirectionRight && self.visibleState != RNSwipeVisibleRight) {
            [self _placeContainerBehindCenterContainer:_leftContainer];
        }
    }

    // ending a pan gesture
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        nowDragging = NO;
        RNSwipeVisible old = self.visibleState;
        
        CGFloat gorizontalVelocity = [recognizer velocityInView:recognizer.view].x;
        if (self.easyOpening && abs(gorizontalVelocity) > kRNSwipeMinVelocityToForceShow) {
            [self fastOpenWithVelocity:gorizontalVelocity];
        }
        // seems redundant, but it isn't
        else if (_centerContainer.left > self.leftVisibleWidth / 2.f) {
            [self showLeftWithRemainingDurationAndInertia:NO];
        }
        else if (_centerContainer.left < (self.rightVisibleWidth / -2.f)) {
            [self showRightWithRemainingDurationAndInertia:NO];
        }
        else {
            // not enough visible area, clear the scene
            CGFloat duration = [self _remainingDuration:abs(_centerContainer.left) threshold:self.leftVisibleWidth];
            [self _layoutContainersAnimated:YES duration:duration];
            self.visibleState = RNSwipeVisibleCenter;
        }

        if (self.visibleState == old) {
            [self setController:self.visibleController active:YES];
        }
    }

    if (recognizer.state == UIGestureRecognizerStateCancelled) {
        nowDragging = NO;
    }
}

#pragma mark - Tap Gesture

- (void)centerViewWasTapped:(UITapGestureRecognizer*)recognizer {
    if (!nowDragging)
        [self _layoutContainersAnimated:YES duration:kRNSwipeDefaultDuration];
}

@end
