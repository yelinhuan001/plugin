// ClassDumpSearch.m
// 仅做 Runtime 检索与报告导出，不会 Hook 或修改会员状态

#import "ClassDumpSearch.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

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

+ (BOOL)string:(NSString *)haystack containsKeyword:(NSString *)keyword {
    if (haystack.length == 0 || keyword.length == 0) return NO;
    return [haystack rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound;
}

+ (NSString *)matchTypeString:(CDSMatchType)type {
    switch (type) {
        case CDSMatchTypeClassName:      return @"类名";
        case CDSMatchTypeInstanceMethod: return @"实例方法";
        case CDSMatchTypeClassMethod:    return @"类方法";
        case CDSMatchTypeProperty:       return @"属性";
    }
    return @"未知";
}

+ (BOOL)isAppOwnClass:(Class)cls {
    const char *imageName = class_getImageName(cls);
    if (!imageName) return NO;
    NSString *img = @(imageName);
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    if (bundlePath.length > 0 && [img hasPrefix:bundlePath]) {
        return YES;
    }
    NSString *exe = [[NSBundle mainBundle] executablePath];
    if (exe.length > 0 && [img isEqualToString:exe]) {
        return YES;
    }
    return NO;
}

+ (void)appendResult:(NSMutableArray<CDSMatchResult *> *)results
           className:(NSString *)className
           matchType:(CDSMatchType)type
                name:(NSString *)name
          maxResults:(NSUInteger)maxResults
{
    if (maxResults > 0 && results.count >= maxResults) return;

    CDSMatchResult *r = [CDSMatchResult new];
    r.className = className;
    r.matchType = type;
    r.name = name ?: className;
    [results addObject:r];
}

+ (NSArray<CDSMatchResult *> *)searchWithKeyword:(NSString *)keyword
                                      maxResults:(NSUInteger)maxResults
{
    if (keyword.length == 0) return @[];

    NSMutableArray<CDSMatchResult *> *results = [NSMutableArray array];
    @autoreleasepool {
        int numClasses = objc_getClassList(NULL, 0);
        if (numClasses <= 0) return @[];

        Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * (size_t)numClasses);
        if (!classes) return @[];

        numClasses = objc_getClassList(classes, numClasses);

        for (int i = 0; i < numClasses; i++) {
            if (maxResults > 0 && results.count >= maxResults) break;

            Class cls = classes[i];
            if (!cls) continue;

            if (sSearchAppOwnOnly && ![self isAppOwnClass:cls]) {
                continue;
            }

            const char *cName = class_getName(cls);
            if (!cName || cName[0] == '\0') continue;

            NSString *className = @(cName);

            // 1) 类名
            if ([self string:className containsKeyword:keyword]) {
                [self appendResult:results
                         className:className
                         matchType:CDSMatchTypeClassName
                              name:className
                        maxResults:maxResults];
            }

            // 2) 实例方法
            unsigned int methodCount = 0;
            Method *methods = class_copyMethodList(cls, &methodCount);
            if (methods) {
                for (unsigned int m = 0; m < methodCount; m++) {
                    if (maxResults > 0 && results.count >= maxResults) break;
                    SEL sel = method_getName(methods[m]);
                    NSString *methodName = NSStringFromSelector(sel);
                    if ([self string:methodName containsKeyword:keyword]) {
                        [self appendResult:results
                                 className:className
                                 matchType:CDSMatchTypeInstanceMethod
                                      name:methodName
                                maxResults:maxResults];
                    }
                }
                free(methods);
            }

            // 3) 类方法（元类）
            Class meta = object_getClass(cls);
            if (meta && meta != cls) {
                unsigned int cmCount = 0;
                Method *cMethods = class_copyMethodList(meta, &cmCount);
                if (cMethods) {
                    for (unsigned int m = 0; m < cmCount; m++) {
                        if (maxResults > 0 && results.count >= maxResults) break;
                        SEL sel = method_getName(cMethods[m]);
                        NSString *methodName = NSStringFromSelector(sel);
                        if ([self string:methodName containsKeyword:keyword]) {
                            [self appendResult:results
                                     className:className
                                     matchType:CDSMatchTypeClassMethod
                                          name:methodName
                                    maxResults:maxResults];
                        }
                    }
                    free(cMethods);
                }
            }

            // 4) 属性
            unsigned int propCount = 0;
            objc_property_t *props = class_copyPropertyList(cls, &propCount);
            if (props) {
                for (unsigned int p = 0; p < propCount; p++) {
                    if (maxResults > 0 && results.count >= maxResults) break;
                    const char *pName = property_getName(props[p]);
                    if (!pName) continue;
                    NSString *propName = @(pName);
                    if ([self string:propName containsKeyword:keyword]) {
                        [self appendResult:results
                                 className:className
                                 matchType:CDSMatchTypeProperty
                                      name:propName
                                maxResults:maxResults];
                    }
                }
                free(props);
            }
        }

        free(classes);
    }
    return [results copy];
}

+ (NSString *)generateReportAndCopyToPasteboard:(NSString *)keyword
                                     maxResults:(NSUInteger)maxResults
{
    NSArray<CDSMatchResult *> *results = [self searchWithKeyword:keyword maxResults:maxResults];
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";

    NSMutableString *md = [NSMutableString string];
    [md appendString:@"# iOS 应用逆向分析报告\n"];
    [md appendFormat:@"## 搜索关键词: %@\n", keyword];
    [md appendFormat:@"## Bundle ID: %@\n", bundleId];
    [md appendString:@"----\n"];
    [md appendFormat:@"找到 %lu 个相关结果：\n", (unsigned long)results.count];
    [md appendString:@"\n> 本报告仅供分析使用，未修改任何运行时状态。\n\n"];

    [results enumerateObjectsUsingBlock:^(CDSMatchResult *r, NSUInteger idx, BOOL *stop) {
        [md appendFormat:@"%lu. [%@]\n", (unsigned long)(idx + 1), r.className];
        [md appendFormat:@"   匹配类型：%@\n", [self matchTypeString:r.matchType]];
        [md appendFormat:@"   名称：%@\n", r.name];
    }];

    NSString *report = [md copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIPasteboard generalPasteboard].string = report;
    });

    NSLog(@"[ClassDumpSearch] report copied, %lu hits for \"%@\"",
          (unsigned long)results.count, keyword);
    return report;
}

@end
