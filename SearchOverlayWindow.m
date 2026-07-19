#import <UIKit/UIKit.h>
#import "SearchOverlayWindow.h"
#import "MethodHacker.h"

@implementation SearchOverlayWindow

+ (instancetype)sharedInstance {
    static SearchOverlayWindow *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithFrame:[UIScreen mainScreen].bounds];
        instance.windowLevel = UIWindowLevelStatusBar - 2;
        instance.rootViewController = [UIViewController new];
        instance.hidden = YES;
    });
    return instance;
}

- (void)showTip:(NSString *)title msg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self makeKeyAndVisible];
        [self.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}
@end
