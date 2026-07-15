//
// TDPFloatingBall.h — iOS 14 悬浮球 + 面板
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TDPFloatingBall : NSObject

+ (instancetype)shared;

- (void)startIfNeeded;
- (void)setVisible:(BOOL)visible;
- (void)showPanel;
- (void)hidePanel;
- (void)toast:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
