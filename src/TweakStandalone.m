//
// TweakStandalone.m — 巨魔通用插件入口（防闪退版）
// 默认：不强制会员、不自动去广告；仅可选悬浮球，全部手动操作
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <unistd.h>
#import "TDPConfig.h"
#import "TDPFloatingBall.h"
#import "TDPVipEngine.h"
#import "TDPAdBlocker.h"

#define TDPLog(fmt, ...) NSLog(@"[TrollDylibPlugin] " fmt, ##__VA_ARGS__)

static NSString * const kPluginVersion = @"2.1.0-safe";

static id sActiveObs = nil;
static BOOL sBooted = NO;

static BOOL TDP_ShouldActivate(void) {
    @try {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        if (bid.length == 0) return NO;

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
        if ([bid hasPrefix:@"com.apple."]) return NO;
        return YES;
    } @catch (__unused NSException *e) {
        return NO;
    }
}

/// 仅在用户打开了「启动自动应用」时执行；默认不会跑
static void TDP_ApplyFeatures(void) {
    @try {
        TDPConfig *cfg = TDPConfig.shared;
        if (cfg.forceVip) {
            NSInteger n = [TDPVipEngine.shared applyForceVip];
            TDPLog(@"forceVip written~%ld", (long)n);
        }
        if (cfg.blockAds) {
            [TDPAdBlocker.shared install];
        }
    } @catch (NSException *e) {
        TDPLog(@"ApplyFeatures exception: %@", e);
    }
}

static void TDP_DoBoot(void) {
    if (sBooted) return;
    sBooted = YES;

    @try {
        if (!TDP_ShouldActivate()) {
            TDPLog(@"skip %@", [[NSBundle mainBundle] bundleIdentifier] ?: @"?");
            return;
        }

        UIApplication *app = [UIApplication sharedApplication];
        if (!app) {
            TDPLog(@"no UIApplication yet");
            sBooted = NO;
            return;
        }

        TDPConfig *cfg = TDPConfig.shared;
        TDPLog(@"boot v%@ forceVip=%d blockAds=%d autoApply=%d",
               kPluginVersion, cfg.forceVip, cfg.blockAds, cfg.autoApply);

        // 默认 autoApply=NO：启动时不扫、不 Hook，避免闪退
        if (cfg.autoApply) {
            TDP_ApplyFeatures();
        }

        if (cfg.showFloatingBall) {
            [TDPFloatingBall.shared startIfNeeded];
        }

        if (cfg.toastEnabled && cfg.showFloatingBall) {
            [TDPFloatingBall.shared toast:
             [NSString stringWithFormat:@"工具箱 v%@\n点「魔」手动操作", kPluginVersion]];
        }
    } @catch (NSException *e) {
        TDPLog(@"boot exception: %@", e);
        sBooted = NO;
    }
}

static void TDP_ScheduleBoot(void) {
    // 进入前台后再等几秒，给 App 初始化时间
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        TDP_DoBoot();
    });
}

static void TDP_Bootstrap(void) {
    @autoreleasepool {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"(null)";
        TDPLog(@"v%@ pid=%d bundle=%@ (safe entry)", kPluginVersion, getpid(), bid);

        // 主线程注册通知；constructor 里绝不直接建 Window / Hook
        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
                if (!sActiveObs) {
                    sActiveObs = [nc addObserverForName:UIApplicationDidBecomeActiveNotification
                                                 object:nil
                                                  queue:[NSOperationQueue mainQueue]
                                             usingBlock:^(__unused NSNotification *note) {
                        TDP_ScheduleBoot();
                        @try {
                            if (TDPConfig.shared.blockAds) {
                                [TDPAdBlocker.shared scrubVisibleAds];
                            }
                            if (TDPConfig.shared.showFloatingBall) {
                                [TDPFloatingBall.shared startIfNeeded];
                            }
                        } @catch (__unused NSException *e) {}
                    }];
                }

                UIApplication *app = [UIApplication sharedApplication];
                if (app && app.applicationState == UIApplicationStateActive) {
                    TDP_ScheduleBoot();
                } else {
                    // 兜底：15 秒后再试
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)),
                                   dispatch_get_main_queue(), ^{
                        if (!sBooted) TDP_ScheduleBoot();
                    });
                }
            } @catch (NSException *e) {
                TDPLog(@"bootstrap setup fail: %@", e);
            }
        });
    }
}

__attribute__((constructor))
static void TDP_Entry(void) {
    // 只调度，不碰 UIKit 对象图
    TDP_Bootstrap();
}

__attribute__((destructor))
static void TDP_Exit(void) {
    @try {
        if (sActiveObs) {
            [[NSNotificationCenter defaultCenter] removeObserver:sActiveObs];
            sActiveObs = nil;
        }
    } @catch (__unused NSException *e) {}
    TDPLog(@"unloaded");
}
