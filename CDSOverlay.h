// CDSOverlay.h
// 顶层悬浮搜索面板（手动唤起，不自动改会员）

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CDSOverlay : NSObject

/// 显示搜索面板
+ (void)show;

/// 隐藏搜索面板
+ (void)hide;

@end

NS_ASSUME_NONNULL_END
