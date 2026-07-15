//
// TweakStandalone.m — 无 Theos/Logos 的纯 ObjC 入口
// 配合 Makefile.standalone 编译，产物可直接给 TrollFools 注入
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <unistd.h>
#import "HookHelper.h"
#import "fishhook.h"

#define TDPLog(fmt, ...) NSLog(@"[TrollDylibPlugin] " fmt, ##__VA_ARGS__)

/// 目标 Bundle ID，为空表示不限制（仍会跳过大部分 com.apple.*）
static NSString * const kTargetBundleID = @"";
static NSString * const kPluginVersion  = @"1.0.0";

static BOOL TDP_ShouldActivate(void) {
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    if (bid.length == 0) return NO;
    if ([bid hasPrefix:@"com.apple."] && ![bid isEqualToString:@"com.apple.springboard"]) {
        return NO;
    }
    if (kTargetBundleID.length > 0 && ![bid isEqualToString:kTargetBundleID]) {
        return NO;
    }
    return YES;
}

static void TDP_ShowToast(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (scene.activationState != UISceneActivationStateForegroundActive) continue;
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) { window = w; break; }
                }
                if (window) break;
            }
        }
        if (!window) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            window = UIApplication.sharedApplication.keyWindow;
#pragma clang diagnostic pop
        }
        UIViewController *root = window.rootViewController;
        while (root.presentedViewController) root = root.presentedViewController;
        if (!root) return;

        UIAlertController *alert =
            [UIAlertController alertControllerWithTitle:@"巨魔插件"
                                                message:msg
                                         preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [root presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - Hook: UIViewController viewDidAppear:

static IMP orig_viewDidAppear = NULL;

static void hook_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    if (orig_viewDidAppear) {
        ((void (*)(id, SEL, BOOL))orig_viewDidAppear)(self, _cmd, animated);
    }
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        TDPLog(@"viewDidAppear first hit: %@", NSStringFromClass([self class]));
    });
}

static void TDP_InstallHooks(void) {
    Class cls = NSClassFromString(@"UIViewController");
    BOOL ok = TDP_SwizzleInstanceMethod(cls,
                                        @selector(viewDidAppear:),
                                        (IMP)hook_viewDidAppear,
                                        &orig_viewDidAppear);
    TDPLog(@"swizzle viewDidAppear: %@", ok ? @"OK" : @"FAIL");
}

#pragma mark - 业务扩展示例

/// 在这里写你自己的 Hook / 逻辑
static void TDP_CustomLogic(void) {
    // 示例：读取/修改 UserDefaults
    // NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    // [ud setBool:YES forKey:@"isVip"];
    // [ud synchronize];

    // 示例：Hook 某个 App 私有类
    // Class target = NSClassFromString(@"SomePrivateClass");
    // TDP_SwizzleInstanceMethod(target, @selector(isPremium), (IMP)hook_isPremium, &orig_isPremium);
}

#pragma mark - 入口

__attribute__((constructor))
static void TDP_Entry(void) {
    @autoreleasepool {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"(null)";
        TDPLog(@"loaded v%@ pid=%d bundle=%@", kPluginVersion, getpid(), bid);

        if (!TDP_ShouldActivate()) {
            TDPLog(@"skip %@", bid);
            return;
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            TDP_InstallHooks();
            TDP_CustomLogic();
            NSString *msg = [NSString stringWithFormat:@"插件已注入\n%@\nv%@", bid, kPluginVersion];
            TDP_ShowToast(msg);
        });
    }
}

__attribute__((destructor))
static void TDP_Exit(void) {
    TDPLog(@"unloaded");
}
