#import <UIKit/UIKit.h>
#import "SearchOverlayWindow.h"
#import "MethodHacker.h"

@implementation SearchOverlayWindow

+ (instancetype)sharedInstance {
    static SearchOverlayWindow *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithFrame:[UIScreen mainScreen].bounds];
        // 修复：UIWindowLevelStatusBar 在 iOS 13+ 已废弃，使用数值常量
        instance.windowLevel = 2098.0; // 原 UIWindowLevelStatusBar - 2
        instance.rootViewController = [UIViewController new];
        instance.hidden = YES;
    });
    return instance;
}

- (void)showTip:(NSString *)title msg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [self makeKeyAndVisible];
        [self.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}

@end
