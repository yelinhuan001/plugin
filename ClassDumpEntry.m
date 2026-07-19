#import <UIKit/UIKit.h>

// 前向声明
@interface FloatingButton : UIView
+ (void)show;
+ (void)hide;
@end

@interface ToolboxViewController : UIViewController
+ (void)show;
+ (void)dismiss;
+ (BOOL)isVisible;
@end

static void __attribute__((constructor)) initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 在 keyWindow 上添加浮动按钮
        [FloatingButton show];
        NSLog(@"[Hacker] 插件已注入。点击 🔧 浮动按钮唤出工具箱。");
    });
}
