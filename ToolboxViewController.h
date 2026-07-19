#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 主工具箱控制器 — 5 Tab 面板
@interface ToolboxViewController : UIViewController

+ (void)show;
+ (void)dismiss;
+ (BOOL)isVisible;

@end

NS_ASSUME_NONNULL_END
