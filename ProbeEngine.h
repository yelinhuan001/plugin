#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

/// 探测结果条目
@interface ProbeResult : NSObject
@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *methodName;
@property (nonatomic, assign) BOOL isClassMethod;
@property (nonatomic, copy) NSString *returnType;       // 返回类型编码
@property (nonatomic, strong, nullable) id returnValue; // 调用 getter 获取的值
@property (nonatomic, copy) NSString *matchedKeyword;   // 匹配到的关键词
@property (nonatomic, assign) BOOL isGetter;            // 是否为 getter（无参数方法）
@end

/// 自动探测引擎 - 扫描所有类的特定关键词方法
@interface ProbeEngine : NSObject

/// 设置探测关键词（默认已包含 vip/ad/pay 等常用词）
+ (void)setKeywords:(NSArray<NSString *> *)keywords;
+ (NSArray<NSString *> *)keywords;

/// 执行探测（同步，可能耗时）
/// @param maxClasses 最大扫描类数（0=不限制）
/// @param progress   进度回调（0.0~1.0），可在主队列更新 UI
/// @return 探测结果数组
+ (NSArray<ProbeResult *> *)runProbeWithMaxClasses:(int)maxClasses
                                          progress:(nullable void(^)(float progress, NSString *currentClass))progress;

/// 快速探测：只扫描指定类名的关键词方法
+ (NSArray<ProbeResult *> *)probeClass:(NSString *)className;

/// 格式化探测报告
+ (NSString *)formatReport:(NSArray<ProbeResult *> *)results;

/// 格式化 VIP 专项报告
+ (NSString *)formatVIPReport:(NSArray<ProbeResult *> *)results;

@end

NS_ASSUME_NONNULL_END
