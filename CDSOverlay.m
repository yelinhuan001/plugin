// CDSOverlay.m
// 防闪退：不 makeKeyAndVisible 抢焦点、检查 UIApplication、主线程、异常保护

#import "CDSOverlay.h"
#import "ClassDumpSearch.h"
#import <UIKit/UIKit.h>

@implementation CDSOverlay

static UIWindow *sWindow;
static UITextField *sField;
static UITextView *sResult;
static UIView *sPanel;
static BOOL sSearching;

+ (BOOL)isVisible {
    return sWindow != nil && !sWindow.hidden;
}

+ (BOOL)cds_uiReady {
    @try {
        UIApplication *app = [UIApplication sharedApplication];
        if (!app) return NO;
        // applicationState 在未启动完时可能不安全，仅判断对象存在
        return YES;
    } @catch (__unused NSException *e) {
        return NO;
    }
}

+ (UIWindowScene *)cds_activeScene {
    @try {
        if (@available(iOS 13.0, *)) {
            for (UIScene *sc in [UIApplication sharedApplication].connectedScenes) {
                if (![sc isKindOfClass:[UIWindowScene class]]) continue;
                if (sc.activationState == UISceneActivationStateForegroundActive ||
                    sc.activationState == UISceneActivationStateForegroundInactive) {
                    return (UIWindowScene *)sc;
                }
            }
            for (UIScene *sc in [UIApplication sharedApplication].connectedScenes) {
                if ([sc isKindOfClass:[UIWindowScene class]]) {
                    return (UIWindowScene *)sc;
                }
            }
        }
    } @catch (__unused NSException *e) {}
    return nil;
}

+ (void)show {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self show]; });
        return;
    }

    @try {
        if (![self cds_uiReady]) {
            NSLog(@"[ClassDumpSearch] UI not ready, skip show");
            return;
        }

        if (sWindow && !sWindow.hidden) {
            return;
        }

        if (sWindow) {
            sWindow.hidden = NO;
            return;
        }

        CGRect screenBounds = [UIScreen mainScreen].bounds;
        if (CGRectIsEmpty(screenBounds) || screenBounds.size.width < 1) {
            return;
        }

        UIWindowScene *scene = [self cds_activeScene];
        if (scene) {
            sWindow = [[UIWindow alloc] initWithWindowScene:scene];
            sWindow.frame = screenBounds;
        } else {
            sWindow = [[UIWindow alloc] initWithFrame:screenBounds];
        }

        // 高 window但不要抢 keyWindow：很多 App 对 makeKeyAndVisible 敏感导致闪退
        sWindow.windowLevel = UIWindowLevelStatusBar + 50;
        sWindow.backgroundColor = [UIColor clearColor];
        sWindow.userInteractionEnabled = YES;
        sWindow.hidden = NO;
        // 故意不调用 makeKeyAndVisible

        UIViewController *vc = [UIViewController new];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.frame = screenBounds;

        CGFloat panelW = MIN(screenBounds.size.width - 24.0, 400.0);
        CGFloat panelH = 400.0;
        CGFloat panelX = (screenBounds.size.width - panelW) * 0.5;
        CGFloat panelY = MAX(60.0, screenBounds.size.height * 0.12);

        sPanel = [[UIView alloc] initWithFrame:CGRectMake(panelX, panelY, panelW, panelH)];
        sPanel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.90];
        sPanel.layer.cornerRadius = 12.0;
        sPanel.clipsToBounds = YES;
        sPanel.userInteractionEnabled = YES;

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, panelW - 24, 22)];
        title.text = @"ClassDump 检索（仅分析）";
        title.textColor = [UIColor whiteColor];
        title.font = [UIFont boldSystemFontOfSize:15];
        title.userInteractionEnabled = NO;

        sField = [[UITextField alloc] initWithFrame:CGRectMake(12, 40, panelW - 100, 36)];
        sField.placeholder = @"关键词 如 vip";
        sField.borderStyle = UITextBorderStyleRoundedRect;
        sField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        sField.autocorrectionType = UITextAutocorrectionTypeNo;
        sField.spellCheckingType = UITextSpellCheckingTypeNo;
        sField.returnKeyType = UIReturnKeySearch;
        sField.backgroundColor = [UIColor whiteColor];
        sField.textColor = [UIColor blackColor];
        sField.clearButtonMode = UITextFieldViewModeWhileEditing;

        UIButton *searchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        searchBtn.frame = CGRectMake(panelW - 80, 40, 68, 36);
        [searchBtn setTitle:@"搜索" forState:UIControlStateNormal];
        [searchBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
        [searchBtn addTarget:self action:@selector(onSearch) forControlEvents:UIControlEventTouchUpInside];

        sResult = [[UITextView alloc] initWithFrame:CGRectMake(12, 88, panelW - 24, panelH - 140)];
        sResult.editable = NO;
        sResult.selectable = YES;
        UIFont *mono = [UIFont fontWithName:@"Menlo-Regular" size:11];
        if (!mono) mono = [UIFont systemFontOfSize:11];
        sResult.font = mono;
        sResult.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0];
        sResult.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
        sResult.text = @"使用说明：\n"
                        "1. 输入关键词后点搜索\n"
                        "2. 结果自动复制到剪贴板\n"
                        "3. 仅分析，不会改会员/返回值\n\n"
                        "若 App 异常，请只用 Frida 版脚本。";

        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(12, panelH - 44, panelW - 24, 36);
        [closeBtn setTitle:@"关闭" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        [closeBtn addTarget:self action:@selector(onClose) forControlEvents:UIControlEventTouchUpInside];

        [sPanel addSubview:title];
        [sPanel addSubview:sField];
        [sPanel addSubview:searchBtn];
        [sPanel addSubview:sResult];
        [sPanel addSubview:closeBtn];
        [vc.view addSubview:sPanel];

        // 轻扫关闭（减少误触崩溃面）
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
        [sPanel addGestureRecognizer:pan];

        sWindow.rootViewController = vc;
        // 再次强调：不 makeKeyAndVisible
        sWindow.hidden = NO;

        NSLog(@"[ClassDumpSearch] overlay shown");
    } @catch (NSException *e) {
        NSLog(@"[ClassDumpSearch] show exception: %@", e);
        sWindow = nil;
        sField = nil;
        sResult = nil;
        sPanel = nil;
    }
}

+ (void)hide {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self hide]; });
        return;
    }
    @try {
        [sField resignFirstResponder];
        sWindow.hidden = YES;
        // 彻底释放，避免挂死后台 Scene
        sWindow.rootViewController = nil;
        sWindow = nil;
        sField = nil;
        sResult = nil;
        sPanel = nil;
        sSearching = NO;
    } @catch (__unused NSException *e) {
        sWindow = nil;
    }
}

+ (void)onPan:(UIPanGestureRecognizer *)pan {
    @try {
        CGPoint t = [pan translationInView:sPanel.superview];
        if (pan.state == UIGestureRecognizerStateChanged) {
            sPanel.center = CGPointMake(sPanel.center.x + t.x, sPanel.center.y + t.y);
            [pan setTranslation:CGPointZero inView:sPanel.superview];
        }
    } @catch (__unused NSException *e) {}
}

+ (void)onClose {
    [self hide];
}

+ (void)onSearch {
    if (sSearching) return;

    @try {
        NSString *kw = sField.text ?: @"";
        kw = [kw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (kw.length == 0) {
            sResult.text = @"请输入关键词。";
            return;
        }

        sSearching = YES;
        sResult.text = @"扫描中（仅 App 自身类）…";
        [sField resignFirstResponder];

        NSString *keyword = [kw copy];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSString *report = nil;
            @try {
                report = [ClassDumpSearch searchAndFormatReport:keyword
                                                     maxResults:200
                                                  copyClipboard:YES];
            } @catch (NSException *e) {
                report = [NSString stringWithFormat:@"搜索异常：%@", e.reason ?: @"unknown"];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                sSearching = NO;
                @try {
                    if (sResult) {
                        sResult.text = [(report ?: @"无结果") stringByAppendingString:@"\n\n（已尝试复制到剪贴板）"];
                    }
                } @catch (__unused NSException *e) {}
            });
        });
    } @catch (NSException *e) {
        sSearching = NO;
        sResult.text = [NSString stringWithFormat:@"UI 异常：%@", e.reason ?: @""];
    }
}

@end
