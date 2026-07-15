//
// TweakStandalone.m — 巨魔通用插件入口
// 功能：悬浮球 · 会员扫描/启发式修改 · 去广告（全 App 注入）
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <unistd.h>
#import "TDPConfig.h"
#import "TDPFloatingBall.h"
#import "TDPVipEngine.h"
#import "TDPAdBlocker.h"

#define TDPLog(fmt, ...) NSLog(@"[TrollDylibPlugin] " fmt, ##__VA_ARGS__)

static NSString * const kPluginVersion = @"2.0.0";

/// 是否应在本进程启用（尽量覆盖第三方 App，跳过大部分系统进程）
static BOOL TDP_ShouldActivate(void) {
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    if (bid.length == 0) return NO;

    // 明确跳过的系统/注入工具
    NSArray *skip = @[
        @"com.apple.springboard",
        @"com.apple.SafariViewService",
        @"com.opa334.TrollStore",
        @"com.opa334.TrollStoreLite",
        @"ru.extraterminal.trollfools",
    ];
    for (NSString *s in skip) {
        if ([bid isEqualToString:s]) return NO;
    }

    // 系统守护 / 扩展一般不注入；允许少量带 UI 的
    if ([bid hasPrefix:@"com.apple."]) {
        // 如需调试系统 App 可改这里
        return NO;
    }
    return YES;
}

static void TDP_ApplyFeatures(void) {
    TDPConfig *cfg = TDPConfig.shared;
    if (cfg.forceVip) {
        NSInteger n = [TDPVipEngine.shared applyForceVip];
        TDPLog(@"forceVip written~%ld", (long)n);
    } else {
        // 仅扫描，便于面板查看
        [TDPVipEngine.shared scan];
    }
    if (cfg.blockAds) {
        [TDPAdBlocker.shared install];
    }
}

static void TDP_Bootstrap(void) {
    @autoreleasepool {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"(null)";
        TDPLog(@"v%@ pid=%d bundle=%@", kPluginVersion, getpid(), bid);

        if (!TDP_ShouldActivate()) {
            TDPLog(@"skip %@", bid);
            return;
        }

        // 等 UI 起来
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            TDPConfig *cfg = TDPConfig.shared;

            if (cfg.autoApply) {
                TDP_ApplyFeatures();
            }

            [TDPFloatingBall.shared startIfNeeded];

            if (cfg.toastEnabled) {
                NSString *msg = [NSString stringWithFormat:@"工具箱已加载 v%@\n点悬浮球「魔」打开面板", kPluginVersion];
                [TDPFloatingBall.shared toast:msg];
            }

            TDPLog(@"ready forceVip=%d blockAds=%d", cfg.forceVip, cfg.blockAds);
        });

        // App 回到前台时再 scrub 一次广告
        [[NSNotificationCenter defaultCenter]
         addObserverForName:UIApplicationDidBecomeActiveNotification
         object:nil queue:[NSOperationQueue mainQueue]
         usingBlock:^(__unused NSNotification *note) {
            if (TDPConfig.shared.blockAds) {
                [TDPAdBlocker.shared scrubVisibleAds];
            }
            if (TDPConfig.shared.showFloatingBall) {
                [TDPFloatingBall.shared startIfNeeded];
            }
        }];
    }
}

__attribute__((constructor))
static void TDP_Entry(void) {
    TDP_Bootstrap();
}

__attribute__((destructor))
static void TDP_Exit(void) {
    TDPLog(@"unloaded");
}
