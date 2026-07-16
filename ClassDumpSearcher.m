#import "ClassDumpSearcher.h"
#import <UIKit/UIPasteboard.h>

#pragma mark - SearchMatch

@implementation SearchMatch
- (NSString *)description {
    return [NSString stringWithFormat:@"[%@] %@ · %@", self.className, self.matchType, self.matchName];
}
@end

#pragma mark - ClassDumpSearcher

@implementation ClassDumpSearcher

+ (NSArray<SearchMatch *> *)searchClassesWithKeyword:(NSString *)keyword {
    if (keyword.length == 0) return @[];

    NSString *lowerKeyword = [keyword lowercaseString];
    NSMutableArray<SearchMatch *> *results = [NSMutableArray array];

    // ── 1. 获取当前进程所有已注册的类 ──
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses <= 0) return @[];

    Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classes, numClasses);

    // ── 2. 遍历每个类 ──
    for (int i = 0; i < numClasses; i++) {
        Class cls = classes[i];
        if (!cls) continue;

        NSString *className = NSStringFromClass(cls);
        if (!className) continue;

        BOOL classMatched = NO;

        // ── 2a. 类名匹配 ──
        if ([[className lowercaseString] containsString:lowerKeyword]) {
            classMatched = YES;
            SearchMatch *match = [[SearchMatch alloc] init];
            match.className = className;
            match.matchType = @"类名";
            match.matchName = className;
            [results addObject:match];
        }

        // ── 2b. 遍历实例方法 ──
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(cls, &methodCount);
        for (unsigned int j = 0; j < methodCount; j++) {
            SEL sel = method_getName(methods[j]);
            NSString *selName = NSStringFromSelector(sel);
            if (selName && [[selName lowercaseString] containsString:lowerKeyword]) {
                SearchMatch *match = [[SearchMatch alloc] init];
                match.className = className;
                match.matchType = @"实例方法";
                match.matchName = selName;
                [results addObject:match];
            }
        }
        free(methods);

        // ── 2c. 遍历类方法（通过元类） ──
        Class metaCls = objc_getMetaClass([className UTF8String]);
        if (metaCls && metaCls != cls) {
            unsigned int classMethodCount = 0;
            Method *classMethods = class_copyMethodList(metaCls, &classMethodCount);
            for (unsigned int j = 0; j < classMethodCount; j++) {
                SEL sel = method_getName(classMethods[j]);
                NSString *selName = NSStringFromSelector(sel);
                if (selName && [[selName lowercaseString] containsString:lowerKeyword]) {
                    SearchMatch *match = [[SearchMatch alloc] init];
                    match.className = className;
                    match.matchType = @"类方法";
                    match.matchName = selName;
                    [results addObject:match];
                }
            }
            free(classMethods);
        }

        // ── 2d. 遍历属性 ──
        unsigned int propertyCount = 0;
        objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
        for (unsigned int j = 0; j < propertyCount; j++) {
            NSString *propName = [NSString stringWithUTF8String:property_getName(properties[j])];
            if (propName && [[propName lowercaseString] containsString:lowerKeyword]) {
                if (!classMatched) {
                    SearchMatch *match = [[SearchMatch alloc] init];
                    match.className = className;
                    match.matchType = @"属性";
                    match.matchName = propName;
                    [results addObject:match];
                }
            }
        }
        free(properties);
    }

    free(classes);
    return results;
}

+ (NSString *)formatReportWithResults:(NSArray<SearchMatch *> *)results
                              keyword:(NSString *)keyword {
    NSMutableString *report = [NSMutableString string];

    [report appendString:@"# iOS 应用逆向分析报告\n"];
    [report appendFormat:@"## 搜索关键词: %@\n", keyword];
    [report appendFormat:@"## Bundle ID: %@\n", [self currentBundleID]];
    [report appendString:@"----\n"];

    if (results.count == 0) {
        [report appendString:@"未找到匹配结果。\n"];
        return report;
    }

    [report appendFormat:@"找到 %lu 个相关结果：\n\n", (unsigned long)results.count];

    NSMutableDictionary<NSString *, NSMutableArray<SearchMatch *> *> *grouped = [NSMutableDictionary dictionary];
    for (SearchMatch *match in results) {
        if (!grouped[match.className]) {
            grouped[match.className] = [NSMutableArray array];
        }
        [grouped[match.className] addObject:match];
    }

    __block NSUInteger index = 1;
    NSArray *sortedClassNames = [[grouped allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for (NSString *clsName in sortedClassNames) {
        NSArray *matches = grouped[clsName];
        for (SearchMatch *match in matches) {
            [report appendFormat:@"%lu. **%@**\n", (unsigned long)index, match.className];
            [report appendFormat:@"    - 匹配类型：%@\n", match.matchType];
            [report appendFormat:@"    - 名称：`%@`\n", match.matchName];
            [report appendString:@"\n"];
            index++;
        }
    }

    return report;
}

+ (void)copyReportToPasteboard:(NSString *)report {
    [UIPasteboard generalPasteboard].string = report;
}

+ (NSString *)currentBundleID {
    return [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
}

+ (NSString *)searchAndCopyWithKeyword:(NSString *)keyword {
    NSArray *results = [self searchClassesWithKeyword:keyword];
    NSString *report = [self formatReportWithResults:results keyword:keyword];
    [self copyReportToPasteboard:report];
    NSLog(@"[ClassDump] 已复制 %lu 条结果到剪贴板", (unsigned long)results.count);
    return report;
}

@end
