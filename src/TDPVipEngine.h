//
// TDPVipEngine.h — 会员相关：扫描 / 启发式修改 / 方法 Hook
//
// 说明：仅能处理「纯本地判断」的简单实现。
// 服务端校验、收据验证、加密 Token 等无法本地改成真会员。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TDPVipHit : NSObject
@property (nonatomic, copy) NSString *source;   // UserDefaults / Method / Ivar
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, nullable) NSString *valueDescription;
@property (nonatomic, assign) BOOL looksLikeVipTrue;
@end

@interface TDPVipEngine : NSObject

+ (instancetype)shared;

/// 扫描结果（最近一次）
@property (nonatomic, strong, readonly) NSArray<TDPVipHit *> *lastHits;
@property (nonatomic, copy, readonly) NSString *lastSummary;

/// 扫描 UserDefaults + 已加载类的可疑方法名
- (NSArray<TDPVipHit *> *)scan;

/// 写入常见本地会员 key，并安装布尔方法 Hook
- (NSInteger)applyForceVip;

/// 安装运行时方法 Hook（isVip / isPremium ... 返回 YES）
- (NSInteger)installMethodHooks;

/// 摘要文本，供面板展示
- (NSString *)statusText;

@end

NS_ASSUME_NONNULL_END
