#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

/// 单个匹配结果
@interface SearchMatch : NSObject
@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *matchType;   // @"类名" / @"实例方法" / @"类方法" / @"属性" / @"Ivar"
@property (nonatomic, copy) NSString *matchName;
@property (nonatomic, copy, nullable) NSString *extra; // 如返回类型、属性属性
/// 是否可直接作为方法 Hook（类名/属性会解析到 getter）
@property (nonatomic, assign) BOOL isHookable;
@end

/// Runtime 类信息检索器
@interface ClassDumpSearcher : NSObject

/// 搜索选项
@property (class, nonatomic, assign) BOOL includeSystemClasses; // 默认 NO
@property (class, nonatomic, assign) NSUInteger maxResults;     // 默认 500

/// 在已加载类中搜索关键词（不区分大小写）
+ (NSArray<SearchMatch *> *)searchClassesWithKeyword:(NSString *)keyword;

/// 仅搜索主 Bundle 镜像内的类（更精准）
+ (NSArray<SearchMatch *> *)searchAppClassesWithKeyword:(NSString *)keyword;

/// 将搜索结果格式化为 Markdown 报告
+ (NSString *)formatReportWithResults:(NSArray<SearchMatch *> *)results
                              keyword:(NSString *)keyword;

/// 将报告复制到系统剪贴板
+ (void)copyReportToPasteboard:(NSString *)report;

/// 获取当前 App 的 Bundle ID
+ (NSString *)currentBundleID;

/// 全流程：搜索 → 格式化 → 复制
+ (NSString *)searchAndCopyWithKeyword:(NSString *)keyword;

/// 获取类的完整 dump（方法/属性/ivar）
+ (NSString *)dumpClass:(NSString *)className;

@end

NS_ASSUME_NONNULL_END
