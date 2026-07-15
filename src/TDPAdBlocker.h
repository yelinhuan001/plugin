//
// TDPAdBlocker.h — 启发式去广告（隐藏广告视图 + 拦截常见广告 SDK 方法）
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TDPAdBlocker : NSObject

+ (instancetype)shared;

@property (nonatomic, assign, readonly) NSInteger hiddenViewCount;
@property (nonatomic, assign, readonly) NSInteger hookedCount;
@property (nonatomic, copy, readonly) NSString *lastSummary;

/// 安装广告相关 Hook（可重复调用）
- (void)install;

/// 遍历当前界面，隐藏疑似广告视图
- (NSInteger)scrubVisibleAds;

- (NSString *)statusText;

@end

NS_ASSUME_NONNULL_END
