#import <UIKit/UIKit.h>

@interface SearchOverlayWindow : UIWindow

/// 获取单例（简版接口，保留兼容）
+ (instancetype)sharedInstance;

/// 显示完整工具箱面板（三Tab UI）
+ (void)show;

/// 关闭工具箱面板
+ (void)dismiss;

/// 显示提示弹窗
- (void)showTip:(NSString *)title msg:(NSString *)msg;

@end
