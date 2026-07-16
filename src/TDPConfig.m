#import "TDPConfig.h"

static NSString * const kShowBall  = @"TDP_showFloatingBall";
static NSString * const kForceVip  = @"TDP_forceVip";
static NSString * const kBlockAds  = @"TDP_blockAds";
static NSString * const kAutoApply = @"TDP_autoApply";
static NSString * const kToast     = @"TDP_toastEnabled";

@implementation TDPConfig

+ (instancetype)shared {
    static TDPConfig *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[TDPConfig alloc] init]; [s reload]; });
    return s;
}

+ (NSString *)prefix { return @"TDP_"; }

- (void)reload {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    // 首次默认：全手动，避免启动自动 Hook 导致闪退
    // forceVip / blockAds / autoApply 全部默认 OFF
    if ([ud objectForKey:kShowBall] == nil)  [ud setBool:YES forKey:kShowBall];
    if ([ud objectForKey:kForceVip] == nil)  [ud setBool:NO  forKey:kForceVip];
    if ([ud objectForKey:kBlockAds] == nil)  [ud setBool:NO  forKey:kBlockAds];
    if ([ud objectForKey:kAutoApply] == nil) [ud setBool:NO  forKey:kAutoApply];
    if ([ud objectForKey:kToast] == nil)     [ud setBool:YES forKey:kToast];
    [ud synchronize];

    _showFloatingBall = [ud boolForKey:kShowBall];
    _forceVip         = [ud boolForKey:kForceVip];
    _blockAds         = [ud boolForKey:kBlockAds];
    _autoApply        = [ud boolForKey:kAutoApply];
    _toastEnabled     = [ud boolForKey:kToast];
}

- (void)save {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    [ud setBool:_showFloatingBall forKey:kShowBall];
    [ud setBool:_forceVip         forKey:kForceVip];
    [ud setBool:_blockAds         forKey:kBlockAds];
    [ud setBool:_autoApply        forKey:kAutoApply];
    [ud setBool:_toastEnabled     forKey:kToast];
    [ud synchronize];
}

- (void)setShowFloatingBall:(BOOL)v { _showFloatingBall = v; [self save]; }
- (void)setForceVip:(BOOL)v         { _forceVip = v; [self save]; }
- (void)setBlockAds:(BOOL)v         { _blockAds = v; [self save]; }
- (void)setAutoApply:(BOOL)v        { _autoApply = v; [self save]; }
- (void)setToastEnabled:(BOOL)v     { _toastEnabled = v; [self save]; }

@end
