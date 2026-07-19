#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import 'SearchOverlayWindow.h'

static BOOL _volumeBtnPressed = NO;
static NSInteger _volumePressCount = 0;

static void __attribute__((constructor)) initialize() {
    // 延迟加载，等 App 启动完成
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 方法1：双指长按 0.6 秒（主入口）
        UIApplication *app = [UIApplication sharedApplication];
        UIWindow *keyWindow = nil;
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
        if (!keyWindow) keyWindow = [app windows].firstObject;

        if (keyWindow) {
            // 双指长按手势
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
                initWithTarget:[SearchOverlayWindow class] action:@selector(show)];
            longPress.numberOfTouchesRequired = 2;
            longPress.minimumPressDuration = 0.6;
            longPress.allowableMovement = 10;
            [keyWindow addGestureRecognizer:longPress];
            NSLog(@'[Hacker] 双指长按 0.6s 已注册');
        }

        // 方法2：音量+连按 3 次（备用入口）
        // 监听音量按钮事件
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
            object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            // 注册音量键监听
            MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-2000, -2000, 0, 0)];
            volumeView.hidden = YES;
            [keyWindow addSubview:volumeView];

            // 监听音量变化
            [[NSNotificationCenter defaultCenter] addObserverForName:@'AVSystemController_SystemVolumeDidChangeNotification'
                object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note2) {
                _volumePressCount++;
                if (_volumePressCount >= 3) {
                    _volumePressCount = 0;
                    [SearchOverlayWindow show];
                }
                // 2秒内没按满3次则重置
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), ^{
                    _volumePressCount = 0;
                });
            }];
        }];

        NSLog(@'[Hacker] 插件已注入。双指长按 0.6s 或 音量+连按3次 唤出面板。');
    });
}
