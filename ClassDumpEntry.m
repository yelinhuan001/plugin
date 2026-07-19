#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import "SearchOverlayWindow.h"

static NSInteger _volumePressCount = 0;

static void __attribute__((constructor)) initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIApplication *app = [UIApplication sharedApplication];
        UIWindow *keyWindow = nil;

        // 获取活跃的 keyWindow
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
        if (!keyWindow) keyWindow = app.keyWindow;

        if (keyWindow) {
            // === 入口1: 双指长按 0.6s ===
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
                initWithTarget:[SearchOverlayWindow class] action:@selector(show)];
            longPress.numberOfTouchesRequired = 2;
            longPress.minimumPressDuration = 0.6;
            longPress.allowableMovement = 10;
            [keyWindow addGestureRecognizer:longPress];
        }

        // === 入口2: 音量+连按3次 ===
        // 用一个隐藏的 MPVolumeView 来截获音量键事件
        MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-2000, -2000, 0, 0)];
        volumeView.hidden = YES;
        [keyWindow addSubview:volumeView];

        [[NSNotificationCenter defaultCenter] addObserverForName:@"AVSystemController_SystemVolumeDidChangeNotification"
            object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            _volumePressCount++;
            if (_volumePressCount >= 3) {
                _volumePressCount = 0;
                [SearchOverlayWindow show];
            }
            // 2秒内没按满3次则重置计数
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                _volumePressCount = 0;
            });
        }];

        NSLog(@"[Hacker] 插件已注入。双指长按0.6s 或 音量+连按3次 唤出面板。");
    });
}
