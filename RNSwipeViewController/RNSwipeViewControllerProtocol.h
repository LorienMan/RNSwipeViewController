@protocol RNSwipeViewControllerProtocol
@property (nonatomic, assign) BOOL active;

@optional
- (void)controllerBecameActiveInContainer;

@optional
- (void)controllerBecameInactiveInContainer;

@end