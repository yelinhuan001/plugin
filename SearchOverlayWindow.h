#import <UIKit/UIKit.h>

@interface SearchOverlayWindow : UIWindow
+ (instancetype)sharedInstance;
- (void)showTip:(NSString *)title msg:(NSString *)msg;
@end
