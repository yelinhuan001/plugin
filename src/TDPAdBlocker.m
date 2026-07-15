#import "TDPAdBlocker.h"
#import "HookHelper.h"
#import "TDPConfig.h"
#import <objc/runtime.h>

static BOOL TDP_ClassNameLooksLikeAd(NSString *name) {
    if (name.length == 0) return NO;
    NSString *n = name;
    // 常见国内/国际广告 SDK 与类名片段
    NSArray *hints = @[
        @"AdView", @"ADView", @"Advert", @"Advertisement", @"BannerAd", @"BannerView",
        @"NativeAd", @"Interstitial", @"RewardVideo", @"Rewarded", @"SplashAd",
        @"GDT", @"GDTMob", @"BUAd", @"BUNative", @"BUSplash", @"CSJ", @"Zeus",
        @"KSAd", @"KSSplash", @"BaiduMob", @"BaiduAd", @"MobAd", @"ToBid",
        @"WindAd", @"Sigmob", @"Mintegral", @"UnityAds", @"Vungle", @"AppLovin",
        @"GADBanner", @"GADInterstitial", @"DFPBanner", @"FBAd", @"FacebookAd",
        @"AdMob", @"GoogleAd", @"MTGAd", @"AnyThink", @"ATAd", @"Pangle",
        @"InMobi", @"Chartboost", @"IronSource", @"AdColony", @"Tapjoy",
        @"UMAd", @"UMengAd", @"TTAd", @"TikTokAd", @"BytedanceAd",
        @"AdSlot", @"AdManager", @"AdLoader", @"OpenAd", @"FullScreenAd"
    ];
    for (NSString *h in hints) {
        if ([n containsString:h]) return YES;
    }
    // 短匹配：类名以 Ad 结尾且较长
    if (n.length > 6 && ([n hasSuffix:@"Ad"] || [n hasSuffix:@"AD"] || [n hasSuffix:@"Ads"])) {
        if (![n hasPrefix:@"UI"] && ![n hasPrefix:@"NS"]) return YES;
    }
    return NO;
}

static void TDP_HideIfAdView(UIView *view, NSInteger *counter) {
    if (!view) return;
    NSString *cn = NSStringFromClass(view.class);
    if (TDP_ClassNameLooksLikeAd(cn)) {
        if (!view.hidden || view.alpha > 0.01) {
            view.hidden = YES;
            view.alpha = 0;
            view.userInteractionEnabled = NO;
            // 尽量去掉高度
            for (NSLayoutConstraint *c in view.constraints) {
                if (c.firstAttribute == NSLayoutAttributeHeight) {
                    c.constant = 0;
                }
            }
            CGRect f = view.frame;
            if (f.size.height > 0) {
                f.size.height = 0;
                view.frame = f;
            }
            if (counter) (*counter)++;
        }
        return; // 已是广告根视图，子树不必再扫
    }
    for (UIView *sub in view.subviews) {
        TDP_HideIfAdView(sub, counter);
    }
}

// 空实现：常见 load 方法
static void TDP_Noop(id self, SEL _cmd) {}
static void TDP_Noop1(id self, SEL _cmd, id a) {}
static void TDP_Noop2(id self, SEL _cmd, id a, id b) {}
static BOOL TDP_ReturnNO(id self, SEL _cmd) { return NO; }
static id TDP_ReturnNil(id self, SEL _cmd) { return nil; }

@interface TDPAdBlocker ()
@property (nonatomic, assign, readwrite) NSInteger hiddenViewCount;
@property (nonatomic, assign, readwrite) NSInteger hookedCount;
@property (nonatomic, copy, readwrite) NSString *lastSummary;
@property (nonatomic, assign) BOOL installed;
@property (nonatomic, strong) NSTimer *scrubTimer;
@end

@implementation TDPAdBlocker

+ (instancetype)shared {
    static TDPAdBlocker *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[TDPAdBlocker alloc] init]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _lastSummary = @"未启用";
    }
    return self;
}

- (void)install {
    if (!TDPConfig.shared.blockAds) {
        [self.scrubTimer invalidate];
        self.scrubTimer = nil;
        self.lastSummary = @"已关闭去广告";
        return;
    }

    NSInteger hooks = 0;
    // 对已加载类中“像广告”的类，Hook 常见展示方法
    NSArray *selNames = @[
        @"loadAd", @"load", @"loadData", @"showAd", @"show", @"present",
        @"display", @"start", @"requestAd", @"fetchAd", @"render",
        @"showFromViewController:", @"showAdFromRootViewController:",
        @"loadAdData", @"loadSplashAd", @"showSplashAd"
    ];

    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        const char *cname = class_getName(cls);
        if (!cname) continue;
        NSString *cn = [NSString stringWithUTF8String:cname];
        if (!TDP_ClassNameLooksLikeAd(cn)) continue;
        if ([cn hasPrefix:@"TDP"]) continue;

        for (NSString *sn in selNames) {
            SEL sel = NSSelectorFromString(sn);
            Method m = class_getInstanceMethod(cls, sel);
            if (!m) continue;
            unsigned numArgs = method_getNumberOfArguments(m); // self+_cmd+...
            char *ret = method_copyReturnType(m);
            IMP imp = (IMP)TDP_Noop;
            if (ret && ret[0] == 'B') imp = (IMP)TDP_ReturnNO;
            else if (ret && ret[0] == '@') imp = (IMP)TDP_ReturnNil;
            else if (numArgs == 3) imp = (IMP)TDP_Noop1;
            else if (numArgs >= 4) imp = (IMP)TDP_Noop2;
            if (ret) free(ret);

            IMP orig = NULL;
            if (TDP_SwizzleInstanceMethod(cls, sel, imp, &orig)) {
                hooks++;
            }
        }
    }
    if (classes) free(classes);

    self.hookedCount += hooks;
    self.installed = YES;

    // 定时清理界面上的广告视图
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.scrubTimer invalidate];
        __weak typeof(self) weakSelf = self;
        self.scrubTimer = [NSTimer scheduledTimerWithTimeInterval:1.5
                                                         repeats:YES
                                                           block:^(__unused NSTimer *t) {
            if (!TDPConfig.shared.blockAds) return;
            [weakSelf scrubVisibleAds];
        }];
        [[NSRunLoop mainRunLoop] addTimer:self.scrubTimer forMode:NSRunLoopCommonModes];
        [self scrubVisibleAds];
    });

    self.lastSummary = [NSString stringWithFormat:@"Hook 广告方法 +%ld（累计 %ld）\n已隐藏视图 %ld",
                        (long)hooks, (long)self.hookedCount, (long)self.hiddenViewCount];
}

- (NSInteger)scrubVisibleAds {
    if (!TDPConfig.shared.blockAds) return 0;
    NSInteger count = 0;
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        TDP_HideIfAdView(w, &count);
    }
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                TDP_HideIfAdView(w, &count);
            }
        }
    }
    self.hiddenViewCount += count;
    if (count > 0) {
        self.lastSummary = [NSString stringWithFormat:@"本轮隐藏 %ld 个广告视图\n累计隐藏 %ld\nHook 方法 %ld",
                            (long)count, (long)self.hiddenViewCount, (long)self.hookedCount];
    }
    return count;
}

- (NSString *)statusText {
    return self.lastSummary ?: @"";
}

@end
