#import <UIKit/UIKit.h>
#import "SearchOverlayWindow.h"

static void __attribute__((constructor)) initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SearchOverlayWindow *win = [SearchOverlayWindow sharedInstance];
        win.hidden = NO;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:win action:@selector(makeKeyAndVisible)];
        tap.numberOfTouchesRequired = 3; 
        [[[UIApplication sharedApplication] keyWindow] addGestureRecognizer:tap];
        
        NSLog(@"插件已加载，三指点击屏幕唤出界面");
    });
}
