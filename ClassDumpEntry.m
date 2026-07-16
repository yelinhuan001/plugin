#import "SearchOverlayWindow.h"
#import "ClassDumpSearcher.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

#pragma mark - UIApplication 扩展（纯 ObjC Category，无需 Logos）

@interface UIApplication (ClassDumpDylib)
- (void)cd_handleOverlayGesture:(UILongPressGestureRecognizer *)gesture;
- (void)cd_ensureGestureInstalled;
@end

@implementation UIApplication (ClassDumpDylib)

- (void)cd_handleOverlayGesture:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    NSLog(@"[ClassDump] 双指长按触发 → 显示搜索面板");
    [SearchOverlayWindow show];
}

- (void)cd_ensureGestureInstalled {
    // iOS 13+ 用 scene 找 window，避免 keyWindow 返回 nil
    UIWindow *keyWin = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)s;
                for (UIWindow *w in ws.windows) {
                    if (w.isKeyWindow) { keyWin = w; break; }
                }
                if (keyWin) break;
            }
        }
    } else {
        keyWin = [UIApplication sharedApplication].keyWindow;
    }
    if (!keyWin) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self cd_ensureGestureInstalled];
        });
        return;
    }
    NSNumber *installed = objc_getAssociatedObject(keyWin, "_cd_gesture_ok");
    if (installed.boolValue) return;
    UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc]
                                             initWithTarget:self
                                             action:@selector(cd_handleOverlayGesture:)];
    gesture.numberOfTouchesRequired = 2;
    gesture.minimumPressDuration = 0.6;
    gesture.allowableMovement = 50;
    [keyWin addGestureRecognizer:gesture];
    objc_setAssociatedObject(keyWin, "_cd_gesture_ok", @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[ClassDump] ✅ 双指长按手势已安装");
}

@end

#pragma mark - 拦截 UIApplication.sendEvent: 以在首个事件时安装手势
// 使用 Method Swizzle 替代 Logos %hook

static void (*orig_sendEvent)(id, SEL, UIEvent *);

static void swizzled_sendEvent(id self, SEL _cmd, UIEvent *event) {
    orig_sendEvent(self, _cmd, event);

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"[ClassDump] 首个 UIEvent 触发 → 安装双指长按手势");
        [[UIApplication sharedApplication] cd_ensureGestureInstalled];
    });
}

// 拦截 UIWindow.makeKeyAndVisible 作为兜底

static void (*orig_makeKeyAndVisible)(id, SEL);

static void swizzled_makeKeyAndVisible(id self, SEL _cmd) {
    orig_makeKeyAndVisible(self, _cmd);

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [[UIApplication sharedApplication] cd_ensureGestureInstalled];
    });
}

#pragma mark - dylib 入口：自动执行初始化

__attribute__((constructor))
static void ClassDylibInit() {
    NSLog(@"[ClassDump] 🔧 dylib 已加载 — 双指长按 0.6s 呼出搜索面板");

    dispatch_async(dispatch_get_main_queue(), ^{
        // ── Method Swizzle: UIApplication.sendEvent: ──
        Class appClass = [UIApplication class];
        SEL selSendEvent = @selector(sendEvent:);
        Method mSendEvent = class_getInstanceMethod(appClass, selSendEvent);
        if (mSendEvent) {
            orig_sendEvent = (void (*)(id, SEL, UIEvent *))method_getImplementation(mSendEvent);
            method_setImplementation(mSendEvent, (IMP)swizzled_sendEvent);
            NSLog(@"[ClassDump] ✅ Swizzle: UIApplication.sendEvent:");
        }

        // ── Method Swizzle: UIWindow.makeKeyAndVisible ──
        Class winClass = [UIWindow class];
        SEL selMakeKeyVis = @selector(makeKeyAndVisible);
        Method mMakeKeyVis = class_getInstanceMethod(winClass, selMakeKeyVis);
        if (mMakeKeyVis) {
            orig_makeKeyAndVisible = (void (*)(id, SEL))method_getImplementation(mMakeKeyVis);
            method_setImplementation(mMakeKeyVis, (IMP)swizzled_makeKeyAndVisible);
            NSLog(@"[ClassDump] ✅ Swizzle: UIWindow.makeKeyAndVisible:");
        }

        // ── 首次延迟尝试安装手势 ──
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] cd_ensureGestureInstalled];
        });
    });
}
