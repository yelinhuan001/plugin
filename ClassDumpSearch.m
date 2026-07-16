// ClassDumpSearch.m
// 崩溃防护要点：跳过元类、单类 try/catch、不碰 UI、可选只扫 App 自身

#import "ClassDumpSearch.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>

@implementation CDSMatchResult
@end

static BOOL sSearchAppOwnOnly = YES;

@implementation ClassDumpSearch

+ (void)setSearchAppOwnClassesOnly:(BOOL)flag {
    sSearchAppOwnOnly = flag;
}

+ (BOOL)searchAppOwnClassesOnly {
    return sSearchAppOwnOnly;
}

+ (BOOL)cds_contains:(NSString *)haystack keyword:(NSString *)keyword {
    if (![haystack isKindOfClass:[NSString class]] || haystack.length == 0) return NO;
    if (![keyword isKindOfClass:[NSString class]] || keyword.length == 0) return NO;
    return [haystack rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound;
}

+ (NSString *)cds_matchTypeString:(CDSMatchType)type {
    switch (type) {
        case CDSMatchTypeClassName:      return @"类名";
        case CDSMatchTypeInstanceMethod: return @"实例方法";
        case CDSMatchTypeClassMethod:    return @"类方法";
        case CDSMatchTypeProperty:       return @"属性";
        default:                         return @"未知";
    }
}

/// 主程序路径前缀（失败则不过滤，由调用方决定）
+ (NSString *)cds_appBundlePath {
    @try {
        NSBundle *b = [NSBundle mainBundle];
        if (!b) return nil;
        NSString *path = b.bundlePath;
        return path.length ? path : nil;
    } @catch (__unused NSException *e) {
        return nil;
    }
}

+ (BOOL)cds_isAppOwnClass:(Class)cls {
    @try {
        const char *imageName = class_getImageName(cls);
        if (!imageName) return NO;
        NSString *img = [NSString stringWithUTF8String:imageName];
        if (img.length == 0) return NO;

        NSString *bundlePath = [self cds_appBundlePath];
        if (bundlePath.length > 0 && [img hasPrefix:bundlePath]) {
            return YES;
        }

        // 兼容：主可执行文件路径
        NSString *exe = [[NSBundle mainBundle] executablePath];
        if (exe.length > 0 && [img isEqualToString:exe]) {
            return YES;
        }
        return NO;
    } @catch (__unused NSException *e) {
        return NO;
    }
}

+ (void)cds_add:(NSMutableArray<CDSMatchResult *> *)results
      className:(NSString *)className
           type:(CDSMatchType)type
           name:(NSString *)name
          limit:(NSUInteger)maxResults
{
    if (maxResults > 0 && results.count >= maxResults) return;
    if (className.length == 0 || name.length == 0) return;

    CDSMatchResult *r = [CDSMatchResult new];
    r.className = [className copy];
    r.matchType = type;
    r.name = [name copy];
    [results addObject:r];
}

+ (void)cds_scanClass:(Class)cls
              keyword:(NSString *)keyword
              results:(NSMutableArray<CDSMatchResult *> *)results
                limit:(NSUInteger)maxResults
{
    if (!cls) return;
    if (maxResults > 0 && results.count >= maxResults) return;

    // 列表里偶发元类，直接跳过
    if (class_isMetaClass(cls)) return;

    const char *cName = NULL;
    @try {
        cName = class_getName(cls);
    } @catch (__unused NSException *e) {
        return;
    }
    if (!cName || cName[0] == '\0') return;

    // 跳过部分明显系统/私有噪声前缀（仍可通过全扫模式看到更多）
    if (cName[0] == '_') {
        // 允许 App 自己的 _ 前缀类，但系统双下划线噪声多
        if (cName[1] == '_') return;
    }

    NSString *className = nil;
    @try {
        className = [NSString stringWithUTF8String:cName];
    } @catch (__unused NSException *e) {
        return;
    }
    if (className.length == 0) return;

    @try {
        if ([self cds_contains:className keyword:keyword]) {
            [self cds_add:results className:className type:CDSMatchTypeClassName name:className limit:maxResults];
        }
    } @catch (__unused NSException *e) {}

    // 实例方法
    @try {
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(cls, &methodCount);
        if (methods) {
            for (unsigned int i = 0; i < methodCount; i++) {
                if (maxResults > 0 && results.count >= maxResults) break;
                @try {
                    Method m = methods[i];
                    if (!m) continue;
                    SEL sel = method_getName(m);
                    if (!sel) continue;
                    NSString *methodName = NSStringFromSelector(sel);
                    if ([self cds_contains:methodName keyword:keyword]) {
                        [self cds_add:results className:className type:CDSMatchTypeInstanceMethod name:methodName limit:maxResults];
                    }
                } @catch (__unused NSException *e) {
                    continue;
                }
            }
            free(methods);
        }
    } @catch (__unused NSException *e) {}

    // 类方法：元类
    @try {
        Class meta = object_getClass((id)cls);
        if (meta && meta != cls && class_isMetaClass(meta)) {
            unsigned int cmCount = 0;
            Method *cMethods = class_copyMethodList(meta, &cmCount);
            if (cMethods) {
                for (unsigned int i = 0; i < cmCount; i++) {
                    if (maxResults > 0 && results.count >= maxResults) break;
                    @try {
                        Method m = cMethods[i];
                        if (!m) continue;
                        SEL sel = method_getName(m);
                        if (!sel) continue;
                        NSString *methodName = NSStringFromSelector(sel);
                        if ([self cds_contains:methodName keyword:keyword]) {
                            [self cds_add:results className:className type:CDSMatchTypeClassMethod name:methodName limit:maxResults];
                        }
                    } @catch (__unused NSException *e) {
                        continue;
                    }
                }
                free(cMethods);
            }
        }
    } @catch (__unused NSException *e) {}

    // 属性
    @try {
        unsigned int propCount = 0;
        objc_property_t *props = class_copyPropertyList(cls, &propCount);
        if (props) {
            for (unsigned int i = 0; i < propCount; i++) {
                if (maxResults > 0 && results.count >= maxResults) break;
                @try {
                    objc_property_t p = props[i];
                    if (!p) continue;
                    const char *pName = property_getName(p);
                    if (!pName) continue;
                    NSString *propName = [NSString stringWithUTF8String:pName];
                    if ([self cds_contains:propName keyword:keyword]) {
                        [self cds_add:results className:className type:CDSMatchTypeProperty name:propName limit:maxResults];
                    }
                } @catch (__unused NSException *e) {
                    continue;
                }
            }
            free(props);
        }
    } @catch (__unused NSException *e) {}
}

+ (NSArray<CDSMatchResult *> *)searchWithKeyword:(NSString *)keyword
                                      maxResults:(NSUInteger)maxResults
{
    if (![keyword isKindOfClass:[NSString class]] || keyword.length == 0) {
        return @[];
    }

    NSString *kw = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (kw.length == 0) return @[];

    NSMutableArray<CDSMatchResult *> *results = [NSMutableArray array];

    @autoreleasepool {
        int numClasses = 0;
        @try {
            numClasses = objc_getClassList(NULL, 0);
        } @catch (__unused NSException *e) {
            return @[];
        }
        if (numClasses <= 0 || numClasses > 500000) {
            // 异常大数量保护
            return @[];
        }

        Class *classes = (__unsafe_unretained Class *)calloc((size_t)numClasses, sizeof(Class));
        if (!classes) return @[];

        int got = 0;
        @try {
            got = objc_getClassList(classes, numClasses);
        } @catch (__unused NSException *e) {
            free(classes);
            return @[];
        }
        if (got <= 0) {
            free(classes);
            return @[];
        }
        if (got > numClasses) got = numClasses;

        for (int i = 0; i < got; i++) {
            if (maxResults > 0 && results.count >= maxResults) break;

            Class cls = classes[i];
            if (!cls) continue;

            @try {
                if (sSearchAppOwnOnly && ![self cds_isAppOwnClass:cls]) {
                    continue;
                }
                [self cds_scanClass:cls keyword:kw results:results limit:maxResults];
            } @catch (__unused NSException *e) {
                continue;
            }
        }

        free(classes);
    }

    return [results copy];
}

+ (NSString *)formatReportWithKeyword:(NSString *)keyword
                              results:(NSArray<CDSMatchResult *> *)results
{
    NSString *bundleId = @"unknown";
    @try {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        if (bid.length) bundleId = bid;
    } @catch (__unused NSException *e) {}

    NSMutableString *md = [NSMutableString string];
    [md appendString:@"# iOS 应用逆向分析报告\n"];
    [md appendFormat:@"## 搜索关键词: %@\n", keyword ?: @""];
    [md appendFormat:@"## Bundle ID: %@\n", bundleId];
    [md appendString:@"----\n"];
    [md appendFormat:@"找到 %lu 个相关结果：\n\n", (unsigned long)results.count];
    [md appendString:@"> 仅分析导出，未修改任何运行时状态。\n\n"];

    NSUInteger idx = 0;
    for (CDSMatchResult *r in results) {
        idx++;
        @try {
            [md appendFormat:@"%lu. [%@]\n", (unsigned long)idx, r.className ?: @"?"];
            [md appendFormat:@"   匹配类型：%@\n", [self cds_matchTypeString:r.matchType]];
            [md appendFormat:@"   名称：%@\n", r.name ?: @"?"];
        } @catch (__unused NSException *e) {
            continue;
        }
    }
    return [md copy];
}

+ (void)cds_copyToPasteboard:(NSString *)text {
    if (text.length == 0) return;
    // 必须主线程；且 UIApplication 已存在时更安全
    void (^block)(void) = ^{
        @try {
            UIApplication *app = [UIApplication sharedApplication];
            if (!app) return;
            [UIPasteboard generalPasteboard].string = text;
        } @catch (__unused NSException *e) {
            NSLog(@"[ClassDumpSearch] pasteboard failed: %@", e);
        }
    };
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

+ (NSString *)searchAndFormatReport:(NSString *)keyword
                         maxResults:(NSUInteger)maxResults
                      copyClipboard:(BOOL)copyClipboard
{
    NSArray<CDSMatchResult *> *results = nil;
    @try {
        results = [self searchWithKeyword:keyword maxResults:maxResults];
    } @catch (NSException *e) {
        NSLog(@"[ClassDumpSearch] search exception: %@", e);
        results = @[];
    }

    NSString *report = [self formatReportWithKeyword:keyword results:results ?: @[]];
    if (copyClipboard) {
        [self cds_copyToPasteboard:report];
    }
    NSLog(@"[ClassDumpSearch] %lu hits for \"%@\"", (unsigned long)results.count, keyword);
    return report;
}

@end
