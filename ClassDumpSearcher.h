#import <Foundation/Foundation.h>

@interface ClassDumpSearcher : NSObject

/// 搜索类名包含关键词的类
+ (NSArray *)searchClassesWithKeyword:(NSString *)keyword;

/// 搜索并生成可复制报告（自动复制到剪贴板），返回报告文本
+ (NSString *)searchAndCopyWithKeyword:(NSString *)keyword;

@end
