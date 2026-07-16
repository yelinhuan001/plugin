#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

/// 单个匹配结果
@interface SearchMatch : NSObject
@property (nonatomic, strong) NSString *className;
@property (nonatomic, strong) NSString *matchType;   // @"类名" / @"实例方法" / @"类方法" / @"属性"
@property (nonatomic, strong) NSString *matchName;
@end

/// Runtime 类信息检索器
@interface ClassDumpSearcher : NSObject

/// 在主 Bundle 及所有已加载类中搜索关键词（不区分大小写）
/// @param keyword 搜索关键词
/// @return 匹配结果数组
+ (NSArray<SearchMatch *> *)searchClassesWithKeyword:(NSString *)keyword;

/// 将搜索结果格式化为 Markdown 报告
/// @param results 搜索结果
/// @param keyword 搜索关键词
/// @return Markdown 格式的字符串
+ (NSString *)formatReportWithResults:(NSArray<SearchMatch *> *)results
                              keyword:(NSString *)keyword;

/// 将报告复制到系统剪贴板
/// @param report 报告文本
+ (void)copyReportToPasteboard:(NSString *)report;

/// 获取当前 App 的 Bundle ID
+ (NSString *)currentBundleID;

/// 全流程：搜索 → 格式化 → 复制到剪贴板，返回报告文本
+ (NSString *)searchAndCopyWithKeyword:(NSString *)keyword;

@end

NS_ASSUME_NONNULL_END
