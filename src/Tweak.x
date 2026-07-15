//
// Tweak.x — iOS 14 巨魔 dylib 插件主逻辑
//
// 两种加载方式:
//   1) 越狱 + Substrate/ElleKit: 自动注入（需 Filter plist）
//   2) 巨魔 TrollStore + TrollFools: 手动注入到目标 App
//
// 无 Substrate 时，下面 %hook 不会生效；构造函数里的
// ObjC Swizzle / fishhook 仍可工作（适合巨魔纯注入）。
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "HookHelper.h"
#import "fishhook.h"

// 日志开关
#ifndef TDP_LOG
#define TDP_LOG 1
#endif

#if TDP_LOG
#define TDPLog(fmt, ...) NSLog(@"[TrollDylibPlugin] " fmt, ##__VA_ARGS__)
#else
#define TDPLog(fmt, ...)
#endif

#pragma mark - 配置区（按需修改）

/// 目标 Bundle ID（为空则对所有进程生效；建议限定）
static NSString * const kTargetBundleID = @""; // 例如 @"com.tencent.xin"

/// 插件版本
static NSString * const kPluginVersion = @"1.0.0";

#pragma mark - 工具

static BOOL TDP_ShouldActivate(void) {
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    if (bid.length == 0) return NO;
    // 跳过系统守护进程等
    if ([bid hasPrefix:@"com.apple."] && ![bid isEqualToString:@"com.apple.springboard"]) {
        return NO;
    }
    if (kTargetBundleID.length > 0 && ![bid isEqualToString:kTargetBundleID]) {
        return NO;
    }
    return YES;
}

#pragma mark - 示例 1: UIAlertController 弹窗提示（验证注入成功）

static void TDP_ShowToast(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *w in scene.windows) {
                        if (w.isKeyWindow) { window = w; break; }
                    }
                }
                if (window) break;
            }
        }
        if (!window) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            window = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
        }
        UIViewController *root = window.rootViewController;
        while (root.presentedViewController) root = root.presentedViewController;
        if (!root) return;

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"巨魔插件"
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [root presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - 示例 2: Method Swizzle（无需 Substrate）

// 钩住 -[UIViewController viewDidAppear:]
static IMP orig_viewDidAppear = NULL;

static void hook_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    ((void (*)(id, SEL, BOOL))orig_viewDidAppear)(self, _cmd, animated);
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        TDPLog(@"viewDidAppear hooked on %@", NSStringFromClass([self class]));
    });
}

static void TDP_InstallViewControllerHook(void) {
    Class cls = NSClassFromString(@"UIViewController");
    if (!cls) return;
    BOOL ok = TDP_SwizzleInstanceMethod(cls,
                                        @selector(viewDidAppear:),
                                        (IMP)hook_viewDidAppear,
                                        &orig_viewDidAppear);
    TDPLog(@"UIViewController viewDidAppear swizzle: %@", ok ? @"OK" : @"FAIL");
}

#pragma mark - 示例 3: fishhook 钩 C 函数（可选）

// 示例：钩 open（演示用，生产请慎用，影响面大）
/*
static int (*orig_open)(const char *, int, ...);
static int hook_open(const char *path, int flags, ...) {
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
        TDPLog(@"open(\"%s\", %d, %d)", path, flags, mode);
        return orig_open(path, flags, mode);
    }
    TDPLog(@"open(\"%s\", %d)", path, flags);
    return orig_open(path, flags);
}
*/

#pragma mark - 示例 4: Logos %hook（仅越狱 + Substrate 生效）

%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL ret = %orig;
    TDPLog(@"UIApplication didFinishLaunching (Logos path)");
    return ret;
}

%end

#pragma mark - 插件入口

__attribute__((constructor))
static void TDP_Entry(void) {
    @autoreleasepool {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"(null)";
        TDPLog(@"loaded v%@ in %@", kPluginVersion, bid);

        if (!TDP_ShouldActivate()) {
            TDPLog(@"skip activate for %@", bid);
            return;
        }

        // 延迟到主 runloop，避免过早操作 UI
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            TDP_InstallViewControllerHook();

            // 首次启动提示（验证注入成功；确认后可注释掉）
            NSString *msg = [NSString stringWithFormat:@"插件已注入\nBundle: %@\nv%@", bid, kPluginVersion];
            TDP_ShowToast(msg);
        });

        /*
        // fishhook 示例（按需打开）
        struct rebinding binds[] = {
            { "open", (void *)hook_open, (void **)&orig_open },
        };
        rebind_symbols(binds, 1);
        */
    }
}

__attribute__((destructor))
static void TDP_Exit(void) {
    TDPLog(@"unloaded");
}
