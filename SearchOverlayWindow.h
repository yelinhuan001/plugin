#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 悬浮搜索覆盖窗口 — 在目标 App 顶层显示搜索框和结果面板
@interface SearchOverlayWindow : UIWindow

/// 显示搜索界面（从 App 任意位置调用）
+ (void)show;

/// 关闭搜索界面
+ (void)dismiss;

@end

NS_ASSUME_NONNULL_END
