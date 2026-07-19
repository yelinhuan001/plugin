#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "ClassDumpSearcher.h"
#import <objc/runtime.h>

@implementation ClassDumpSearcher

+ (NSArray *)searchClassesWithKeyword:(NSString *)keyword {
    NSMutableArray *results = [NSMutableArray array];
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses > 0) {
        Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        NSString *lowerKeyword = [keyword lowercaseString];
        for (int i = 0; i < numClasses; i++) {
            NSString *className = NSStringFromClass(classes[i]);
            // 过滤系统类（以 _ 开头或包含 UIKit/Foundation 前缀）
            if ([className hasPrefix:@"_"]) continue;
            if ([className hasPrefix:@"UI"] && ![className hasPrefix:@"UI"]) continue;
            if (keyword.length == 0 || [[className lowercaseString] containsString:lowerKeyword]) {
                [results addObject:className];
            }
        }
        free(classes);
    }
    return [results sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

+ (NSString *)searchAndCopyWithKeyword:(NSString *)keyword {
    NSArray *classes = [self searchClassesWithKeyword:keyword];

    NSMutableString *report = [NSMutableString string];
    [report appendFormat:@"🔍 搜索结果: 「%@」\n", keyword ?: @"全部"];
    [report appendFormat:@"共找到 %lu 个类\n\n", (unsigned long)classes.count];

    for (NSString *className in classes) {
        [report appendFormat:@"• %@\n", className];
        [report appendFormat:@"  ├─ 父类: %@\n", NSStringFromClass([NSClassFromString(className) superclass]) ?: @"(根类)"];

        // 列出部分实例方法
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(NSClassFromString(className), &methodCount);
        if (methodCount > 0) {
            [report appendFormat:@"  └─ 方法 (%d):\n", methodCount];
            // 只显示前 20 个方法
            unsigned int showCount = MIN(methodCount, 20);
            for (unsigned int j = 0; j < showCount; j++) {
                SEL sel = method_getName(methods[j]);
                NSString *selName = NSStringFromSelector(sel);
                // 过滤无关的 getter/setter
                if ([selName hasPrefix:@"."]) continue;
                [report appendFormat:@"       %@\n", selName];
            }
            if (methodCount > 20) {
                [report appendFormat:@"       ... 还有 %d 个方法\n", methodCount - 20];
            }
        } else {
            [report appendFormat:@"  └─ (无实例方法)\n"];
        }
        free(methods);
    }

    // 自动复制到剪贴板
    [UIPasteboard generalPasteboard].string = report;

    return report;
}

@end
