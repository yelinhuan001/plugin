// ClassDumpSearch.h
// Runtime Class / Method / Property 检索（仅分析，不修改任何返回值）

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CDSMatchType) {
    CDSMatchTypeClassName = 0,
    CDSMatchTypeInstanceMethod,
    CDSMatchTypeClassMethod,
    CDSMatchTypeProperty
};

@interface CDSMatchResult : NSObject
@property (nonatomic, copy) NSString *className;
@property (nonatomic, assign) CDSMatchType matchType;
/// 方法名 / 属性名；类名匹配时可与 className 相同
@property (nonatomic, copy) NSString *name;
@end

@interface ClassDumpSearch : NSObject

/// 在当前进程已注册的 ObjC 类中搜索关键词（不区分大小写）
/// @param keyword 搜索词，如 @"vip"
/// @param maxResults 最大结果数，0 表示不限制
+ (NSArray<CDSMatchResult *> *)searchWithKeyword:(NSString *)keyword
                                      maxResults:(NSUInteger)maxResults;

/// 生成 Markdown 报告并写入系统剪贴板
+ (NSString *)generateReportAndCopyToPasteboard:(NSString *)keyword
                                     maxResults:(NSUInteger)maxResults;

/// 是否仅搜索 App 自身 image 中的类（减少系统库噪声）
+ (void)setSearchAppOwnClassesOnly:(BOOL)flag;
+ (BOOL)searchAppOwnClassesOnly;

@end

NS_ASSUME_NONNULL_END
