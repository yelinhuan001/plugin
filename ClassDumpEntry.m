#import "SearchOverlayWindow.h"
#import "ClassDumpSearcher.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Helpers

static UIWindow *CD_FindKeyWindow(void) {
    UIWindow *keyWin = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if (![s isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)s;
            if (ws.activationState != UISceneActivationStateForegroundActive &&
                ws.activationState != UISceneActivationStateForegroundInactive) {
                continue;
            }
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) { keyWin = w; break; }
            }
            if (keyWin) break;
            // 退而取第一个可见 window
            for (UIWindow *w in ws.windows) {
                if (!w.hidden && w.alpha > 0.01 && w.rootViewController) {
                    keyWin = w;
                    break;
                }
            }
            if (keyWin) break;
        }
        // 再扫一遍所有 scene
        if (!keyWin) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if (![s isKindOfClass:[UIWindowScene class]]) continue;
                for (UIWindow *w in ((UIWindowScene *)s).windows) {
                    if (!w.hidden && w.rootViewController) {
                        keyWin = w;
                        break;
                    }
                }
                if (keyWin) break;
            }
        }
    }
    if (!keyWin) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWin = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
    }
    if (!keyWin) {
        keyWin = [UIApplication sharedApplication].windows.firstObject;
    }
    return keyWin;
}

#pragma mark - UIApplication Category

@interface UIApplication (ClassDumpDylib)
- (void)cd_handleOverlayGesture:(UILongPressGestureRecognizer *)gesture;
- (void)cd_ensureGestureInstalled;
- (void)cd_installOnWindow:(UIWindow *)window;
@end

@implementation UIApplication (ClassDumpDylib)

- (void)cd_handleOverlayGesture:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    NSLog(@"[ClassDump] 双指长按触发 → 显示搜索面板");
    dispatch_async(dispatch_get_main_queue(), ^{
        [SearchOverlayWindow show];
    });
}

- (void)cd_installOnWindow:(UIWindow *)window {
    if (!window) return;
    // 跳过我们自己的覆盖层
    if ([window isKindOfClass:[SearchOverlayWindow class]]) return;
    if (window.windowLevel > 2000) return;

    NSNumber *installed = objc_getAssociatedObject(window, _cmd);
    if (installed.boolValue) return;

    UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc]
                                             initWithTarget:self
                                             action:@selector(cd_handleOverlayGesture:)];
    gesture.numberOfTouchesRequired = 2;
    gesture.minimumPressDuration = 0.6;
    gesture.allowableMovement = 80;
    gesture.cancelsTouchesInView = NO;
    gesture.delaysTouchesBegan = NO;
    [window addGestureRecognizer:gesture];
    objc_setAssociatedObject(window, _cmd, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[ClassDump] ✅ 双指长按已安装 → %@", window);
}

- (void)cd_ensureGestureInstalled {
    // 安装到所有可见 window，避免 keyWindow 切换失效
    NSMutableSet *wins = [NSMutableSet set];
    UIWindow *key = CD_FindKeyWindow();
    if (key) [wins addObject:key];

    if (@available(iOS 13.0, *)) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if (![s isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)s).windows) {
                if (w) [wins addObject:w];
            }
        }
    }
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w) [wins addObject:w];
    }

    if (wins.count == 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self cd_ensureGestureInstalled];
        });
        return;
    }

    for (UIWindow *w in wins) {
        [self cd_installOnWindow:w];
    }
}

@end

#pragma mark - Swizzle

static void (*orig_sendEvent)(id, SEL, UIEvent *);
static void (*orig_makeKeyAndVisible)(id, SEL);

static void swizzled_sendEvent(id self, SEL _cmd, UIEvent *event) {
    if (orig_sendEvent) orig_sendEvent(self, _cmd, event);

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"[ClassDump] 首个 UIEvent → 安装手势");
        [[UIApplication sharedApplication] cd_ensureGestureInstalled];
    });
}

static void swizzled_makeKeyAndVisible(id self, SEL _cmd) {
    if (orig_makeKeyAndVisible) orig_makeKeyAndVisible(self, _cmd);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] cd_ensureGestureInstalled];
    });
}

#pragma mark - Volume button fallback (triple volume-up in 2s opens panel)

@interface CDVolumeWatcher : NSObject
@property (nonatomic, assign) NSInteger upCount;
@property (nonatomic, assign) CFTimeInterval windowStart;
@end

@implementation CDVolumeWatcher
+ (instancetype)shared {
    static CDVolumeWatcher *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [CDVolumeWatcher new]; });
    return s;
}
- (void)start {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(volChanged:)
                                                 name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                               object:nil];
    // 也监听更通用的
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(volChanged:)
                                                 name:@"SystemVolumeDidChange"
                                               object:nil];
}
- (void)volChanged:(NSNotification *)note {
    // 部分系统通知带 reason；无 reason 也计数（可能误触，需连按 3 次）
    CFTimeInterval now = CACurrentMediaTime();
    if (now - self.windowStart > 2.0) {
        self.windowStart = now;
        self.upCount = 0;
    }
    self.upCount++;
    if (self.upCount >= 3) {
        self.upCount = 0;
        NSLog(@"[ClassDump] 音量键连按 → 打开面板");
        dispatch_async(dispatch_get_main_queue(), ^{
            [SearchOverlayWindow show];
        });
    }
}
@end

#pragma mark - Entry

__attribute__((constructor))
static void ClassDylibInit(void) {
    NSLog(@"[ClassDump] 🔧 dylib 已加载 — 双指长按 0.6s 或 音量+连按3次 呼出面板");

    dispatch_async(dispatch_get_main_queue(), ^{
        Class appClass = [UIApplication class];
        Method mSendEvent = class_getInstanceMethod(appClass, @selector(sendEvent:));
        if (mSendEvent) {
            orig_sendEvent = (void (*)(id, SEL, UIEvent *))method_getImplementation(mSendEvent);
            method_setImplementation(mSendEvent, (IMP)swizzled_sendEvent);
            NSLog(@"[ClassDump] ✅ Swizzle: UIApplication.sendEvent:");
        }

        Class winClass = [UIWindow class];
        Method mMakeKeyVis = class_getInstanceMethod(winClass, @selector(makeKeyAndVisible));
        if (mMakeKeyVis) {
            orig_makeKeyAndVisible = (void (*)(id, SEL))method_getImplementation(mMakeKeyVis);
            method_setImplementation(mMakeKeyVis, (IMP)swizzled_makeKeyAndVisible);
            NSLog(@"[ClassDump] ✅ Swizzle: UIWindow.makeKeyAndVisible");
        }

        // 延迟安装 + 重试
        void (^install)(void) = ^{
            [[UIApplication sharedApplication] cd_ensureGestureInstalled];
        };
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), install);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), install);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), install);

        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *n) {
            install();
        }];

        [[CDVolumeWatcher shared] start];
    });
}
