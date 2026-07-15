//
// TDPConfig.h — 插件开关（按 App 沙盒持久化）
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TDPConfig : NSObject

+ (instancetype)shared;

/// 是否显示悬浮球（默认 YES）
@property (nonatomic, assign) BOOL showFloatingBall;
/// 启发式强制会员（默认 NO，需用户手动开）
@property (nonatomic, assign) BOOL forceVip;
/// 去广告（默认 YES）
@property (nonatomic, assign) BOOL blockAds;
/// 启动后自动应用会员/广告策略（默认 YES）
@property (nonatomic, assign) BOOL autoApply;
/// 弹窗提示重要操作（默认 YES）
@property (nonatomic, assign) BOOL toastEnabled;

- (void)reload;
- (void)save;

/// 插件专用 key 前缀，避免与业务 key 混淆
+ (NSString *)prefix;

@end

NS_ASSUME_NONNULL_END
