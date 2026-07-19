#import <UIKit/UIKit.h>
#import "SearchOverlayWindow.h"

static void __attribute__((constructor)) initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIApplication *app = [UIApplication sharedApplication];
        UIWindow *keyWindow = nil;

        // 获取活跃的 keyWindow（兼容 iOS 13+ 多窗口场景）
        if (@available(iOS 13.0, *)) {
            for (UIScene *s in app.connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *ws = (UIWindowScene *)s;
                    if (ws.activationState == UISceneActivationStateForegroundActive) {
                        for (UIWindow *w in ws.windows) {
                            if (w.isKeyWindow) { keyWindow = w; break; }
                        }
                        if (!keyWindow) keyWindow = [ws.windows firstObject];
                        break;
                    }
                }
            }
        }
        if (!keyWindow) keyWindow = [app keyWindow];

        if (keyWindow) {
            // 双指长按 0.6 秒呼出工具箱（主入口）
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
                initWithTarget:[SearchOverlayWindow class] action:@selector(show)];
            longPress.numberOfTouchesRequired = 2;
            longPress.minimumPressDuration = 0.6;
            longPress.allowableMovement = 10;
            [keyWindow addGestureRecognizer:longPress];
            NSLog(@"[Hacker] 插件已注入。双指长按 0.6s 唤出面板。");
        }
    });
}
