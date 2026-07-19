#import <UIKit/UIKit.h>
#import "ProbeEngine.h"

@implementation ProbeResult
@end

#pragma mark -

@interface ProbeEngine ()
@property (class, strong) NSArray<NSString *> *customKeywords;
@end

@implementation ProbeEngine

static NSArray<NSString *> *_customKeywords = nil;
static NSArray<NSString *> *_defaultKeywords = nil;

+ (NSArray<NSString *> *)defaultKeywords {
    if (!_defaultKeywords) {
        _defaultKeywords = @[
            // VIP / 会员
            @"vip", @"svip", @"premium", @"member", @"pro",
            @"isvip", @"isVIP", @"vipuser", @"vipUser",
            @"getVip", @"getvip", @"vipLevel", @"viplevel",
            @"vipStatus", @"vipstatus", @"vipInfo", @"vipinfo",
            @"isPremium", @"ispro", @"isPro",
            // 广告
            @"ad", @"advert", @"banner", @"interstitial",
            @"rewarded", @"shouldShowAd", @"canDisplayAd",
            @"isAd", @"showAd", @"loadAd", @"enableAd",
            @"hasAd", @"removeAd",
            // 支付/解锁
            @"purchase", @"buy", @"pay", @"unlock",
            @"subscription", @"subscribe", @"transaction",
            @"isPurchased", @"hasPurchased", @"isLocked",
            // Token/认证
            @"token", @"auth", @"login", @"session",
            @"isLogin", @"isLoggedIn", @"isAuth",
            // 其他
            @"trial", @"quota", @"limit", @"feature",
            @"enable", @"license", @"jailbreak",
            @"hook", @"detect", @"check",
        ];
    }
    return _defaultKeywords;
}

+ (NSArray<NSString *> *)keywords {
    return _customKeywords ?: [self defaultKeywords];
}

+ (void)setKeywords:(NSArray<NSString *> *)keywords {
    _customKeywords = [keywords copy];
}

+ (BOOL)isSystemClass:(NSString *)className {
    // 过滤系统类
    if ([className hasPrefix:@"_"]) return YES;
    if ([className hasPrefix:@"UI"]) return YES;
    if ([className hasPrefix:@"NS"]) return YES;
    if ([className hasPrefix:@"CF"]) return YES;
    if ([className hasPrefix:@"CA"]) return YES;
    if ([className hasPrefix:@"MK"]) return YES;
    if ([className hasPrefix:@"AV"]) return YES;
    if ([className hasPrefix:@"CIImage"]) return YES;
    if ([className hasPrefix:@"CIFilter"]) return YES;
    if ([className hasPrefix:@"PH"]) return YES;
    if ([className hasPrefix:@"SK"]) return YES;
    if ([className hasPrefix:@"SCN"]) return YES;
    if ([className hasPrefix:@"AR"]) return YES;
    if ([className hasPrefix:@"CL"]) return YES;
    if ([className hasPrefix:@"EK"]) return YES;
    if ([className hasPrefix:@"AB"]) return YES;
    if ([className hasPrefix:@"JS"]) return YES;
    if ([className hasPrefix:@"WK"]) return YES;
    if ([className hasPrefix:@"SFS"]) return YES;
    if ([className hasPrefix:@"SFU"]) return YES;
    if ([className hasPrefix:@"LA"]) return YES;
    if ([className hasPrefix:@"Sec"]) return YES;
    if ([className hasPrefix:@"CBC"]) return YES;
    // 只包含一个字母的类名忽略
    if (className.length <= 2) return YES;
    return NO;
}

+ (BOOL)methodMatchesKeyword:(NSString *)methodName keywords:(NSArray<NSString *> *)keywords matched:(NSString **)matched {
    NSString *lower = [methodName lowercaseString];
    for (NSString *kw in keywords) {
        NSString *lowerKw = [kw lowercaseString];
        if ([lower containsString:lowerKw]) {
            *matched = kw;
            return YES;
        }
    }
    return NO;
}

+ (NSArray<ProbeResult *> *)runProbeWithMaxClasses:(int)maxClasses
                                          progress:(void (^)(float, NSString *))progress
{
    NSMutableArray<ProbeResult *> *results = [NSMutableArray array];
    NSArray *keywords = [self keywords];

    int totalClasses = objc_getClassList(NULL, 0);
    int limit = (maxClasses > 0) ? MIN(totalClasses, maxClasses) : totalClasses;

    if (limit > 0) {
        Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * totalClasses);
        objc_getClassList(classes, totalClasses);

        int processed = 0;
        for (int i = 0; i < totalClasses && processed < limit; i++) {
            @autoreleasepool {
                NSString *className = NSStringFromClass(classes[i]);
            if ([self isSystemClass:className]) continue;
            if ([className hasPrefix:@"Probe"]) continue; // 过滤自己
            if ([className hasPrefix:@"Search"]) continue;

            processed++;
            if (progress) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progress((float)processed / limit, className);
                });
            }

            @autoreleasepool {
                // 探测实例方法
                [self probeMethodsForClass:classes[i]
                                 className:className
                               isClassMethod:NO
                                  keywords:keywords
                                   results:results];

                // 探测类方法
                [self probeMethodsForClass:object_getClass(classes[i])
                                 className:className
                               isClassMethod:YES
                                  keywords:keywords
                                   results:results];
            }
            }
        }
        free(classes);
    }

    // 去重
    NSMutableSet *seen = [NSMutableSet set];
    NSMutableArray *unique = [NSMutableArray array];
    for (ProbeResult *r in results) {
        NSString *key = [NSString stringWithFormat:@"%@.%@.%d", r.className, r.methodName, r.isClassMethod];
        if (![seen containsObject:key]) {
            [seen addObject:key];
            [unique addObject:r];
        }
    }

    return [unique copy];
}

+ (void)probeMethodsForClass:(Class)cls
                   className:(NSString *)className
                isClassMethod:(BOOL)isClassMethod
                   keywords:(NSArray<NSString *> *)keywords
                    results:(NSMutableArray<ProbeResult *> *)results
{
    if (!cls) return;

    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);

    for (unsigned int j = 0; j < methodCount; j++) {
        SEL sel = method_getName(methods[j]);
        NSString *methodName = NSStringFromSelector(sel);

        // 过滤属性存取方法和内部方法
        if ([methodName hasPrefix:@"."]) continue;
        if ([methodName hasPrefix:@"_"]) continue;
        if ([methodName hasSuffix:@":"]) continue; // 有参数的方法暂不探测

        NSString *matched = nil;
        if (![self methodMatchesKeyword:methodName keywords:keywords matched:&matched]) {
            continue;
        }

        ProbeResult *result = [ProbeResult new];
        result.className = className;
        result.methodName = methodName;
        result.isClassMethod = isClassMethod;
        result.matchedKeyword = matched;
        result.isGetter = YES;

        // 获取返回类型（安全：只读取编码，不调用方法）
        char returnType[256] = {0};
        method_getReturnType(methods[j], returnType, sizeof(returnType));
        result.returnType = [NSString stringWithUTF8String:returnType];
        result.isGetter = YES;
        
        // 注意：不调用实际 getter 以避免 crash
        // 用户可以根据方法名和返回类型手动尝试 Hook
        result.returnValue = nil;

        [results addObject:result];
    }
    free(methods);
}

+ (NSArray<ProbeResult *> *)probeClass:(NSString *)className {
    Class cls = NSClassFromString(className);
    if (!cls) return @[];

    NSMutableArray *results = [NSMutableArray array];
    NSArray *keywords = [self keywords];

    [self probeMethodsForClass:cls className:className isClassMethod:NO keywords:keywords results:results];
    [self probeMethodsForClass:object_getClass(cls) className:className isClassMethod:YES keywords:keywords results:results];

    return [results copy];
}

+ (NSString *)formatReport:(NSArray<ProbeResult *> *)results {
    if (results.count == 0) return @"(无探测结果)";

    NSMutableString *report = [NSMutableString string];
    [report appendFormat:@"🔍 自动探测报告\n"];
    [report appendFormat:@"共发现 %lu 个匹配项\n\n", (unsigned long)results.count];

    // 按关键词分组
    NSMutableDictionary *grouped = [NSMutableDictionary dictionary];
    for (ProbeResult *r in results) {
        NSString *kw = r.matchedKeyword ?: @"其他";
        NSMutableArray *list = grouped[kw];
        if (!list) { list = [NSMutableArray array]; grouped[kw] = list; }
        [list addObject:r];
    }

    for (NSString *kw in [[grouped allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
        NSArray *list = grouped[kw];
        [report appendFormat:@"\n【%@】(%lu 个)\n", kw, (unsigned long)list.count];
        for (ProbeResult *r in list) {
            NSString *type = r.isClassMethod ? @"+" : @"-";
            [report appendFormat:@"  %@[%@ %@]  [%@]\n", type, r.className, r.methodName, r.returnType];
        }
    }

    return report;
}

+ (NSString *)formatVIPReport:(NSArray<ProbeResult *> *)results {
    if (results.count == 0) return @"(未发现 VIP 相关方法)";

    // 过滤 VIP 相关
    NSArray *vipKeywords = @[@"vip", @"svip", @"premium", @"member", @"pro", @"vipuser"];
    NSMutableArray *vipResults = [NSMutableArray array];
    for (ProbeResult *r in results) {
        NSString *lower = [r.methodName lowercaseString];
        for (NSString *kw in vipKeywords) {
            if ([lower containsString:kw]) {
                [vipResults addObject:r];
                break;
            }
        }
    }

    if (vipResults.count == 0) return @"(未发现 VIP 相关方法)";

    NSMutableString *report = [NSMutableString string];
    [report appendFormat:@"🦸 VIP 专项分析\n"];
    [report appendFormat:@"发现 %lu 个 VIP 相关方法\n\n", (unsigned long)vipResults.count];

    for (ProbeResult *r in vipResults) {
        NSString *type = r.isClassMethod ? @"+" : @"-";
        [report appendFormat:@"%@[%@ %@] %@\n", type, r.className, r.methodName, r.returnType];
    }

    [report appendString:@"\n💡 建议：在 Hook 面板中添加对应 Hook"];
    return report;
}

@end
