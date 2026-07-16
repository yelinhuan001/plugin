// CDSOverlay.h
// 悬浮面板：不抢 keyWindow、不自动弹出（由 TweakEntry 安全触发）

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CDSOverlay : NSObject

+ (void)show;
+ (void)hide;
+ (BOOL)isVisible;

@end

NS_ASSUME_NONNULL_END
