#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 🚀 工具箱入口：创建浮动按钮
@interface ToolboxLauncher : NSObject
+ (void)launch;
@end

/// 🔧 浮动按钮（可拖拽）
@interface FloatingButton : UIView
+ (instancetype)sharedButton;
@end

/// 📋 主菜单列表
@interface ToolboxMenuController : UITableViewController
@end

/// 🔍 类搜索
@interface ClassSearchController : UIViewController
@end

/// 🪝 Hook 管理
@interface HookManageController : UITableViewController
@end

/// 📡 运行时探测
@interface ProbeController : UIViewController
@end

/// ⚙️ 默认值编辑器  
@interface DefaultsEditorController : UITableViewController
@end

/// 📋 Hook 日志
@interface HookLogController : UIViewController
@end

NS_ASSUME_NONNULL_END
