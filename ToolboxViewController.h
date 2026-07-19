#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 🔧 浮动按钮
@interface FloatingButton : UIView
+ (instancetype)sharedButton;
@end

/// 📋 主菜单
@interface ToolboxMenuController : UITableViewController
+ (void)show;
@end

/// 🔍 类搜索
@interface ClassSearchController : UIViewController <UITextFieldDelegate>
@end

/// ⚡ 快速 Hook
@interface QuickHookController : UIViewController
@end

/// 🪝 Hook 管理
@interface HookManageController : UITableViewController
@end

/// 📡 探测
@interface ProbeController : UIViewController
@end

/// 🦸 VIP 分析
@interface VIPProbeController : UIViewController
@end

/// ⚙️ UserDefaults
@interface DefaultsEditorController : UITableViewController <UISearchResultsUpdating>
@end

NS_ASSUME_NONNULL_END
