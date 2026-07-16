#import "SearchOverlayWindow.h"
#import "ClassDumpSearcher.h"
#import <objc/runtime.h>

#pragma mark - 添加方法到 UIApplication

@interface UIApplication (ClassDumpTweak)
- (void)handleOverlayGesture:(UILongPressGestureRecognizer *)gesture;
- (void)ensureOverlayGestureInstalled;
@end

@implementation UIApplication (ClassDumpTweak)

- (void)handleOverlayGesture:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    NSLog(@"[ClassDump] 三指长按触发，显示搜索覆盖层");
    [SearchOverlayWindow show];
}

- (void)ensureOverlayGestureInstalled {
    UIWindow *keyWin = self.keyWindow;
    if (keyWin) {
        // 检查是否已安装
        NSNumber *installed = objc_getAssociatedObject(keyWin, "_cd_gesture_ok");
        if (!installed.boolValue) {
            UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc]
                                                     initWithTarget:self
                                                     action:@selector(handleOverlayGesture:)];
            gesture.numberOfTouchesRequired = 3;
            gesture.minimumPressDuration = 0.8;
            gesture.allowableMovement = 50;
            [keyWin addGestureRecognizer:gesture];
            objc_setAssociatedObject(keyWin, "_cd_gesture_ok", @YES,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            NSLog(@"[ClassDump] ✅ 三指长按手势已安装");
        }
    } else {
        NSLog(@"[ClassDump] ⏳ keyWindow 尚不可用，1 秒后重试...");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self ensureOverlayGestureInstalled];
        });
    }
}

@end

#pragma mark - Logos Hooks

// Hook: 首个事件触发时安装手势（比私有 API 更安全）
%hook UIApplication

- (void)sendEvent:(UIEvent *)event {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"[ClassDump] 首个 UIEvent 触发，安装手势");
        [[UIApplication sharedApplication] ensureOverlayGestureInstalled];
    });
}

%end

// Hook: 窗口 makeKeyAndVisible 时兜底安装
%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [[UIApplication sharedApplication] ensureOverlayGestureInstalled];
    });
}

%end

#pragma mark - 构造函数

%ctor {
    NSLog(@"[ClassDump] 🔧 Tweak 已加载 — 三指长按 0.8 秒呼出搜索面板 (iOS 14+)");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] ensureOverlayGestureInstalled];
    });
}
