#import "ClassDumpSearcher.h"
#import <UIKit/UIPasteboard.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

#pragma mark - SearchMatch

@implementation SearchMatch
- (NSString *)description {
    return [NSString stringWithFormat:@"[%@] %@ · %@", self.className, self.matchType, self.matchName];
}
@end

#pragma mark - ClassDumpSearcher

@implementation ClassDumpSearcher

static BOOL _includeSystem = NO;
static NSUInteger _maxResults = 500;

+ (BOOL)includeSystemClasses { return _includeSystem; }
+ (void)setIncludeSystemClasses:(BOOL)v { _includeSystem = v; }
+ (NSUInteger)maxResults { return _maxResults; }
+ (void)setMaxResults:(NSUInteger)v { _maxResults = v > 0 ? v : 500; }

+ (BOOL)isSystemClassName:(NSString *)name {
    if (name.length == 0) return YES;
    static NSArray *prefixes = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        prefixes = @[
            @"NS", @"UI", @"CA", @"CF", @"CG", @"CI", @"CL", @"CM", @"CN", @"CT",
            @"AV", @"MK", @"MT", @"SK", @"WK", @"XC", @"__", @"OS_",
            @"Swift.", @"_Tt", @"JS", @"WebKit", @"PFUbiquity",
            @"SearchOverlay", @"ClassDump", @"MethodHacker", @"UserDefaultsEditor",
            @"_NS", @"_UI", @"__NS", @"__UI"
        ];
    });
    // 以下划线开头的多为私有系统类
    if ([name hasPrefix:@"_"] && ![name hasPrefix:@"_TtC"]) {
        // Swift 模块类 _TtC... 保留（可能是 App）
        if (![name hasPrefix:@"_Tt"]) return YES;
    }
    for (NSString *p in prefixes) {
        if ([name hasPrefix:p]) return YES;
    }
    return NO;
}

+ (BOOL)classBelongsToMainExecutable:(Class)cls {
    if (!cls) return NO;
    Dl_info info;
    if (dladdr((__bridge const void *)cls, &info) == 0 || !info.dli_fname) return NO;
    const char *mainPath = NULL;
    // 索引 0 通常是主可执行文件
    mainPath = _dyld_get_image_name(0);
    if (!mainPath) return YES; // 无法判断时不过滤
    // 主 binary 或同目录 Frameworks
    if (strcmp(info.dli_fname, mainPath) == 0) return YES;
    NSString *path = [NSString stringWithUTF8String:info.dli_fname];
    NSString *main = [NSString stringWithUTF8String:mainPath];
    NSString *appDir = [main stringByDeletingLastPathComponent];
    if ([path hasPrefix:appDir]) return YES;
    return NO;
}

+ (NSArray<SearchMatch *> *)searchClassesWithKeyword:(NSString *)keyword {
    return [self searchWithKeyword:keyword appOnly:NO];
}

+ (NSArray<SearchMatch *> *)searchAppClassesWithKeyword:(NSString *)keyword {
    return [self searchWithKeyword:keyword appOnly:YES];
}

+ (NSArray<SearchMatch *> *)searchWithKeyword:(NSString *)keyword appOnly:(BOOL)appOnly {
    if (keyword.length == 0) return @[];

    NSString *lowerKeyword = keyword.lowercaseString;
    NSMutableArray<SearchMatch *> *results = [NSMutableArray array];
    NSUInteger limit = self.maxResults;

    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses <= 0) return @[];

    Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * (size_t)numClasses);
    if (!classes) return @[];
    numClasses = objc_getClassList(classes, numClasses);

    for (int i = 0; i < numClasses && results.count < limit; i++) {
        @try {
            Class cls = classes[i];
            if (!cls || class_isMetaClass(cls)) continue;

            NSString *className = NSStringFromClass(cls);
            if (!className) continue;
            if (!self.includeSystemClasses && [self isSystemClassName:className]) continue;
            if (appOnly && ![self classBelongsToMainExecutable:cls]) continue;

            // ── 类名 ──
            if ([className.lowercaseString containsString:lowerKeyword]) {
                SearchMatch *match = [SearchMatch new];
                match.className = className;
                match.matchType = @"类名";
                match.matchName = className;
                match.isHookable = NO;
                match.extra = @"点击查看方法列表";
                [results addObject:match];
                if (results.count >= limit) break;
            }

            // ── 实例方法 ──
            unsigned int methodCount = 0;
            Method *methods = class_copyMethodList(cls, &methodCount);
            for (unsigned int j = 0; j < methodCount && results.count < limit; j++) {
                SEL sel = method_getName(methods[j]);
                NSString *selName = NSStringFromSelector(sel);
                if (!selName || ![selName.lowercaseString containsString:lowerKeyword]) continue;

                char *ret = method_copyReturnType(methods[j]);
                NSString *retStr = ret ? [NSString stringWithUTF8String:ret] : @"?";
                if (ret) free(ret);

                SearchMatch *match = [SearchMatch new];
                match.className = className;
                match.matchType = @"实例方法";
                match.matchName = selName;
                match.isHookable = YES;
                match.extra = [NSString stringWithFormat:@"ret=%@ args=%u", retStr, method_getNumberOfArguments(methods[j])];
                [results addObject:match];
            }
            if (methods) free(methods);

            // ── 类方法 ──
            Class metaCls = object_getClass(cls);
            if (metaCls && metaCls != cls) {
                unsigned int classMethodCount = 0;
                Method *classMethods = class_copyMethodList(metaCls, &classMethodCount);
                for (unsigned int j = 0; j < classMethodCount && results.count < limit; j++) {
                    SEL sel = method_getName(classMethods[j]);
                    NSString *selName = NSStringFromSelector(sel);
                    if (!selName || ![selName.lowercaseString containsString:lowerKeyword]) continue;

                    char *ret = method_copyReturnType(classMethods[j]);
                    NSString *retStr = ret ? [NSString stringWithUTF8String:ret] : @"?";
                    if (ret) free(ret);

                    SearchMatch *match = [SearchMatch new];
                    match.className = className;
                    match.matchType = @"类方法";
                    match.matchName = selName;
                    match.isHookable = YES;
                    match.extra = [NSString stringWithFormat:@"ret=%@", retStr];
                    [results addObject:match];
                }
                if (classMethods) free(classMethods);
            }

            // ── 属性 ──
            unsigned int propertyCount = 0;
            objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
            for (unsigned int j = 0; j < propertyCount && results.count < limit; j++) {
                const char *pname = property_getName(properties[j]);
                if (!pname) continue;
                NSString *propName = [NSString stringWithUTF8String:pname];
                if (!propName || ![propName.lowercaseString containsString:lowerKeyword]) continue;

                SearchMatch *match = [SearchMatch new];
                match.className = className;
                match.matchType = @"属性";
                match.matchName = propName;
                match.isHookable = YES;
                match.extra = @"Hook getter";
                [results addObject:match];
            }
            if (properties) free(properties);

            // ── Ivar ──
            unsigned int ivarCount = 0;
            Ivar *ivars = class_copyIvarList(cls, &ivarCount);
            for (unsigned int j = 0; j < ivarCount && results.count < limit; j++) {
                const char *iname = ivar_getName(ivars[j]);
                if (!iname) continue;
                NSString *ivarName = [NSString stringWithUTF8String:iname];
                if (!ivarName || ![ivarName.lowercaseString containsString:lowerKeyword]) continue;

                SearchMatch *match = [SearchMatch new];
                match.className = className;
                match.matchType = @"Ivar";
                match.matchName = ivarName;
                match.isHookable = NO;
                const char *type = ivar_getTypeEncoding(ivars[j]);
                match.extra = type ? [NSString stringWithUTF8String:type] : nil;
                [results addObject:match];
            }
            if (ivars) free(ivars);
        } @catch (__unused NSException *e) {
            continue;
        }
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
    [report appendFormat:@"## App: %@\n",
     [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]
     ?: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]
     ?: @"?"];
    [report appendString:@"----\n"];

    if (results.count == 0) {
        [report appendString:@"未找到匹配结果。\n"];
        [report appendString:@"提示：可尝试更短关键词，或开启系统类搜索。\n"];
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

    NSUInteger index = 1;
    NSArray *sortedClassNames = [[grouped allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for (NSString *clsName in sortedClassNames) {
        for (SearchMatch *match in grouped[clsName]) {
            [report appendFormat:@"%lu. **%@**\n", (unsigned long)index, match.className];
            [report appendFormat:@"    - 匹配类型：%@\n", match.matchType];
            [report appendFormat:@"    - 名称：`%@`\n", match.matchName];
            if (match.extra.length) {
                [report appendFormat:@"    - 附加：%@\n", match.extra];
            }
            [report appendString:@"\n"];
            index++;
        }
    }

    if (results.count >= self.maxResults) {
        [report appendFormat:@"\n> 已达上限 %lu，结果可能被截断。\n", (unsigned long)self.maxResults];
    }

    return report;
}

+ (void)copyReportToPasteboard:(NSString *)report {
    if (report) {
        [UIPasteboard generalPasteboard].string = report;
    }
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

+ (NSString *)dumpClass:(NSString *)className {
    Class cls = NSClassFromString(className);
    if (!cls) return [NSString stringWithFormat:@"类不存在: %@", className];

    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"@interface %@ : %@\n", className, NSStringFromClass(class_getSuperclass(cls)) ?: @"NSObject"];

    unsigned int pcount = 0;
    objc_property_t *props = class_copyPropertyList(cls, &pcount);
    for (unsigned int i = 0; i < pcount; i++) {
        [s appendFormat:@"@property %s;\n", property_getName(props[i])];
    }
    if (props) free(props);

    unsigned int icount = 0;
    Ivar *ivars = class_copyIvarList(cls, &icount);
    for (unsigned int i = 0; i < icount; i++) {
        [s appendFormat:@"    %s %s;\n", ivar_getTypeEncoding(ivars[i]) ?: "?", ivar_getName(ivars[i]) ?: "?"];
    }
    if (ivars) free(ivars);

    unsigned int mcount = 0;
    Method *methods = class_copyMethodList(cls, &mcount);
    for (unsigned int i = 0; i < mcount; i++) {
        char *ret = method_copyReturnType(methods[i]);
        [s appendFormat:@"- (%s)%@;\n", ret ?: "?", NSStringFromSelector(method_getName(methods[i]))];
        if (ret) free(ret);
    }
    if (methods) free(methods);

    Class meta = object_getClass(cls);
    unsigned int cmcount = 0;
    Method *cmethods = class_copyMethodList(meta, &cmcount);
    for (unsigned int i = 0; i < cmcount; i++) {
        char *ret = method_copyReturnType(cmethods[i]);
        [s appendFormat:@"+ (%s)%@;\n", ret ?: "?", NSStringFromSelector(method_getName(cmethods[i]))];
        if (ret) free(ret);
    }
    if (cmethods) free(cmethods);

    [s appendString:@"@end\n"];
    return s;
}

@end
