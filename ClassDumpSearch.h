// ClassDumpSearch.h
// 仅 Runtime 检索与报告，不 Hook、不改返回值、不强制会员

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
@property (nonatomic, copy) NSString *name;
@end

@interface ClassDumpSearch : NSObject

/// 是否只扫主 App bundle 内的类（默认 YES，更稳、更快）
+ (void)setSearchAppOwnClassesOnly:(BOOL)flag;
+ (BOOL)searchAppOwnClassesOnly;

/// 搜索（可在后台线程调用；内部做了异常保护）
+ (NSArray<CDSMatchResult *> *)searchWithKeyword:(NSString *)keyword
                                      maxResults:(NSUInteger)maxResults;

/// 生成 Markdown；可选复制剪贴板（clipboard 必须在主线程安全时再写）
+ (NSString *)formatReportWithKeyword:(NSString *)keyword
                              results:(NSArray<CDSMatchResult *> *)results;

+ (NSString *)searchAndFormatReport:(NSString *)keyword
                         maxResults:(NSUInteger)maxResults
                      copyClipboard:(BOOL)copyClipboard;

@end

NS_ASSUME_NONNULL_END
