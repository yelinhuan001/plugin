#import "TDPVipEngine.h"
#import "HookHelper.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation TDPVipHit
@end

// ---------- 关键词 ----------
static NSArray<NSString *> *TDP_VipKeyHints(void) {
    return @[
        @"vip", @"isvip", @"is_vip", @"vipstatus", @"viptype", @"viplevel",
        @"premium", @"ispremium", @"is_premium", @"member", @"ismember",
        @"is_member", @"membership", @"subscribe", @"subscribed", @"ispro",
        @"is_pro", @"prouser", @"paid", @"ispaid", @"unlock", @"unlocked",
        @"expire", @"expiry", @"expiretime", @"expire_time", @"vipend",
        @"svip", @"issvip", @"super_vip", @"hasvip", @"checkvip",
        @"userType", @"usertype", @"memberType", @"membertype", @"grade",
        @"isLoginVip", @"foreverVip", @"lifetime", @"purchase"
    ];
}

static NSArray<NSString *> *TDP_VipSelectorHints(void) {
    return @[
        @"isVip", @"isVIP", @"isSVip", @"isSVIP", @"isPremium", @"isMember",
        @"isPro", @"isPaid", @"isSubscribed", @"isUnlocked", @"hasVip",
        @"hasVIP", @"checkVip", @"getIsVip", @"vipStatus", @"isLogin",
        @"isValidVip", @"isForeverVip", @"isLifetimeVip", @"canUseVip",
        @"isVipUser", @"isPremiumUser", @"isMemberUser", @"purchased"
    ];
}

static BOOL TDP_StringLooksVipKey(NSString *key) {
    if (key.length == 0) return NO;
    if ([key hasPrefix:@"TDP_"]) return NO; // 跳过插件自己的配置
    NSString *lower = key.lowercaseString;
    for (NSString *h in TDP_VipKeyHints()) {
        if ([lower containsString:h.lowercaseString]) return YES;
    }
    return NO;
}

static BOOL TDP_ValueLooksTrue(id val) {
    if (!val || val == [NSNull null]) return NO;
    if ([val isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)val boolValue] || [(NSNumber *)val integerValue] > 0;
    }
    if ([val isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)val lowercaseString];
        if ([s isEqualToString:@"1"] || [s isEqualToString:@"true"] ||
            [s isEqualToString:@"yes"] || [s isEqualToString:@"vip"] ||
            [s isEqualToString:@"premium"] || [s isEqualToString:@"pro"]) return YES;
        if (s.length > 0 && ![s isEqualToString:@"0"] && ![s isEqualToString:@"false"] &&
            ![s isEqualToString:@"no"] && ![s isEqualToString:@"none"]) {
            // 长 token 也算「有值」
            if (s.length > 8) return YES;
        }
    }
    return NO;
}

// Hook 统一返回 YES 的 BOOL 方法
static BOOL TDP_HookBoolYes(id self, SEL _cmd) {
    return YES;
}

static NSInteger TDP_HookIntOne(id self, SEL _cmd) {
    return 1;
}

@interface TDPVipEngine ()
@property (nonatomic, strong, readwrite) NSArray<TDPVipHit *> *lastHits;
@property (nonatomic, copy, readwrite) NSString *lastSummary;
@property (nonatomic, assign) BOOL methodsHooked;
@property (nonatomic, assign) NSInteger hookedMethodCount;
@end

@implementation TDPVipEngine

+ (instancetype)shared {
    static TDPVipEngine *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[TDPVipEngine alloc] init]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _lastHits = @[];
        _lastSummary = @"尚未扫描";
    }
    return self;
}

#pragma mark - Scan

- (NSArray<TDPVipHit *> *)scan {
    NSMutableArray<TDPVipHit *> *hits = [NSMutableArray array];

    // 1) UserDefaults
    NSDictionary *dict = NSUserDefaults.standardUserDefaults.dictionaryRepresentation;
    for (NSString *key in dict) {
        if (!TDP_StringLooksVipKey(key)) continue;
        id val = dict[key];
        TDPVipHit *h = [TDPVipHit new];
        h.source = @"UserDefaults";
        h.name = key;
        h.valueDescription = [NSString stringWithFormat:@"%@", val];
        h.looksLikeVipTrue = TDP_ValueLooksTrue(val);
        [hits addObject:h];
    }

    // 2) 方法名扫描（限制数量 + 异常隔离，避免闪退）
    unsigned int classCount = 0;
    Class *classes = NULL;
    @try {
        classes = objc_copyClassList(&classCount);
    } @catch (__unused NSException *e) {
        classes = NULL;
        classCount = 0;
    }
    NSInteger methodHits = 0;
    const NSInteger kMaxMethodHits = 80;
    for (unsigned int i = 0; i < classCount && methodHits < kMaxMethodHits; i++) {
        @try {
            Class cls = classes[i];
            if (!cls || class_isMetaClass(cls)) continue;
            const char *cname = class_getName(cls);
            if (!cname) continue;
            if (strncmp(cname, "OS_", 3) == 0) continue;
            if (strncmp(cname, "_", 1) == 0) continue;
            NSString *cn = [NSString stringWithUTF8String:cname];
            if ([cn hasPrefix:@"NS"] || [cn hasPrefix:@"UI"] || [cn hasPrefix:@"CA"] ||
                [cn hasPrefix:@"CF"] || [cn hasPrefix:@"Swift"] || [cn hasPrefix:@"__"]) continue;

            unsigned int mcount = 0;
            Method *methods = class_copyMethodList(cls, &mcount);
            if (!methods) continue;
            for (unsigned int j = 0; j < mcount && methodHits < kMaxMethodHits; j++) {
                SEL sel = method_getName(methods[j]);
                if (!sel) continue;
                NSString *selName = NSStringFromSelector(sel);
                BOOL match = NO;
                for (NSString *hint in TDP_VipSelectorHints()) {
                    if ([selName isEqualToString:hint] ||
                        [selName.lowercaseString containsString:hint.lowercaseString]) {
                        match = YES;
                        break;
                    }
                }
                if (!match) continue;

                char *types = method_copyReturnType(methods[j]);
                NSString *ret = types ? [NSString stringWithUTF8String:types] : @"?";
                if (types) free(types);

                TDPVipHit *h = [TDPVipHit new];
                h.source = @"Method";
                h.name = [NSString stringWithFormat:@"-[%@ %@]", cn, selName];
                h.valueDescription = [NSString stringWithFormat:@"ret=%@", ret];
                h.looksLikeVipTrue = NO;
                [hits addObject:h];
                methodHits++;
            }
            free(methods);
        } @catch (__unused NSException *e) {
            continue;
        }
    }
    if (classes) free(classes);

    self.lastHits = [hits copy];

    NSInteger udCount = 0, mCount = 0, vipTrue = 0;
    for (TDPVipHit *h in hits) {
        if ([h.source isEqualToString:@"UserDefaults"]) {
            udCount++;
            if (h.looksLikeVipTrue) vipTrue++;
        } else mCount++;
    }
    self.lastSummary = [NSString stringWithFormat:
                        @"UserDefaults 可疑项 %ld（疑似已开通 %ld）\n可疑方法 %ld\nHook 方法数 %ld",
                        (long)udCount, (long)vipTrue, (long)mCount, (long)self.hookedMethodCount];
    return self.lastHits;
}

#pragma mark - Force VIP via UserDefaults

- (NSInteger)applyForceVip {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    NSInteger written = 0;

    // 布尔类
    NSArray *boolKeys = @[
        @"isVip", @"isVIP", @"is_vip", @"vip", @"VIP", @"isSVip", @"isSVIP",
        @"isPremium", @"is_premium", @"premium", @"isMember", @"is_member",
        @"isPro", @"is_pro", @"isPaid", @"isSubscribed", @"subscribed",
        @"isUnlocked", @"unlocked", @"hasVip", @"hasVIP", @"foreverVip",
        @"isForeverVip", @"isLifetimeVip", @"vipStatus", @"memberStatus",
        @"isLoginVip", @"userIsVip", @"is_svip", @"svip"
    ];
    for (NSString *k in boolKeys) {
        [ud setBool:YES forKey:k];
        written++;
    }

    // 数值等级
    NSArray *intKeys = @[
        @"vipLevel", @"vip_level", @"vipType", @"vip_type", @"memberType",
        @"member_type", @"userType", @"user_type", @"memberLevel", @"grade"
    ];
    for (NSString *k in intKeys) {
        [ud setInteger:1 forKey:k];
        written++;
    }

    // 过期时间：十年后
    NSTimeInterval tenYears = [[NSDate date] timeIntervalSince1970] + 86400.0 * 365 * 10;
    NSArray *timeKeys = @[
        @"vipExpire", @"vip_expire", @"expireTime", @"expire_time",
        @"expiry", @"vipEndTime", @"vip_end_time", @"memberExpire",
        @"subscriptionExpireDate", @"premiumExpire"
    ];
    for (NSString *k in timeKeys) {
        [ud setDouble:tenYears forKey:k];
        [ud setObject:@((long long)tenYears) forKey:[k stringByAppendingString:@"_ll"]];
        written++;
    }

    // 字符串状态
    [ud setObject:@"vip" forKey:@"userRole"];
    [ud setObject:@"vip" forKey:@"role"];
    [ud setObject:@"premium" forKey:@"accountType"];
    [ud setObject:@"1" forKey:@"vip"];
    written += 4;

    // 把扫描到的已有可疑 key 也强制写成“开通”
    NSDictionary *all = ud.dictionaryRepresentation;
    for (NSString *key in all) {
        if (!TDP_StringLooksVipKey(key)) continue;
        id val = all[key];
        if ([val isKindOfClass:[NSNumber class]]) {
            [ud setBool:YES forKey:key];
            written++;
        } else if ([val isKindOfClass:[NSString class]]) {
            [ud setObject:@"1" forKey:key];
            written++;
        }
    }

    [ud synchronize];

    NSInteger hooks = [self installMethodHooks];
    [self scan];
    self.lastSummary = [NSString stringWithFormat:
                        @"已写入约 %ld 项本地标记\n已 Hook %ld 个可疑方法\n\n%@",
                        (long)written, (long)hooks, self.lastSummary];
    return written;
}

#pragma mark - Method hooks

- (NSInteger)installMethodHooks {
    // 允许重复调用时继续补 Hook（新加载的类）
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    NSInteger hooked = 0;
    const NSInteger kMaxHook = 120;

    for (unsigned int i = 0; i < classCount && hooked < kMaxHook; i++) {
        Class cls = classes[i];
        const char *cname = class_getName(cls);
        if (!cname) continue;
        if (strncmp(cname, "OS_", 3) == 0 || strncmp(cname, "_", 1) == 0) continue;
        NSString *cn = [NSString stringWithUTF8String:cname];
        if ([cn hasPrefix:@"NS"] || [cn hasPrefix:@"UI"] || [cn hasPrefix:@"CA"] ||
            [cn hasPrefix:@"CF"] || [cn hasPrefix:@"TDP"] || [cn hasPrefix:@"__"]) continue;

        for (NSString *selName in TDP_VipSelectorHints()) {
            SEL sel = NSSelectorFromString(selName);
            Method m = class_getInstanceMethod(cls, sel);
            if (!m) continue;

            char *ret = method_copyReturnType(m);
            BOOL isBool = ret && (ret[0] == 'B' || ret[0] == 'c'); // BOOL / char
            BOOL isInt  = ret && (ret[0] == 'i' || ret[0] == 'q' || ret[0] == 'l' ||
                                  ret[0] == 'I' || ret[0] == 'Q' || ret[0] == 's');
            if (ret) free(ret);

            IMP newImp = NULL;
            if (isBool) newImp = (IMP)TDP_HookBoolYes;
            else if (isInt) newImp = (IMP)TDP_HookIntOne;
            else continue;

            // 无参方法才安全 Hook
            NSMethodSignature *sig = [cls instanceMethodSignatureForSelector:sel];
            if (!sig || sig.numberOfArguments != 2) continue; // self, _cmd

            IMP orig = NULL;
            if (TDP_SwizzleInstanceMethod(cls, sel, newImp, &orig)) {
                hooked++;
            }
        }
    }
    if (classes) free(classes);

    self.methodsHooked = YES;
    self.hookedMethodCount += hooked;
    return hooked;
}

- (NSString *)statusText {
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"?";
    NSString *name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (!name) name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"] ?: @"?";
    return [NSString stringWithFormat:@"App: %@\n%@\n\n%@", name, bid, self.lastSummary ?: @""];
}

@end
