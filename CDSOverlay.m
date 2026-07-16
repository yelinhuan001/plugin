// CDSOverlay.m

#import "CDSOverlay.h"
#import "ClassDumpSearch.h"
#import <UIKit/UIKit.h>

@implementation CDSOverlay

static UIWindow *sWindow;
static UITextField *sField;
static UITextView *sResult;

+ (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (sWindow) {
            sWindow.hidden = NO;
            [sWindow makeKeyAndVisible];
            return;
        }

        UIWindowScene *scene = nil;
        for (UIScene *sc in [UIApplication sharedApplication].connectedScenes) {
            if (sc.activationState == UISceneActivationStateForegroundActive &&
                [sc isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)sc;
                break;
            }
        }

        if (scene) {
            sWindow = [[UIWindow alloc] initWithWindowScene:scene];
        } else {
            sWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }

        sWindow.windowLevel = UIWindowLevelAlert + 100;
        sWindow.backgroundColor = [UIColor clearColor];

        UIViewController *vc = [UIViewController new];
        vc.view.backgroundColor = [UIColor clearColor];

        CGFloat W = UIScreen.mainScreen.bounds.size.width;
        UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(20, 80, W - 40, 380)];
        panel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.88];
        panel.layer.cornerRadius = 12;
        panel.clipsToBounds = YES;

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, panel.bounds.size.width - 24, 22)];
        title.text = @"Class Dump 检索（仅分析）";
        title.textColor = UIColor.whiteColor;
        title.font = [UIFont boldSystemFontOfSize:15];

        sField = [[UITextField alloc] initWithFrame:CGRectMake(12, 36, panel.bounds.size.width - 100, 36)];
        sField.placeholder = @"关键词 e.g. vip";
        sField.borderStyle = UITextBorderStyleRoundedRect;
        sField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        sField.autocorrectionType = UITextAutocorrectionTypeNo;
        sField.backgroundColor = UIColor.whiteColor;

        UIButton *searchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        searchBtn.frame = CGRectMake(CGRectGetMaxX(sField.frame) + 8, 36, 70, 36);
        [searchBtn setTitle:@"搜索" forState:UIControlStateNormal];
        [searchBtn setTitleColor:UIColor.cyanColor forState:UIControlStateNormal];
        [searchBtn addTarget:self action:@selector(onSearch) forControlEvents:UIControlEventTouchUpInside];

        sResult = [[UITextView alloc] initWithFrame:CGRectMake(12, 80, panel.bounds.size.width - 24, 250)];
        sResult.editable = NO;
        sResult.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
        sResult.textColor = UIColor.greenColor;
        sResult.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        sResult.text = @"输入关键词后点搜索。\n结果会复制到剪贴板，方便粘贴给 AI。\n\n不会修改任何方法返回值或会员状态。";

        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(12, 338, panel.bounds.size.width - 24, 32);
        [closeBtn setTitle:@"关闭" forState:UIControlStateNormal];
        [closeBtn setTitleColor:UIColor.lightGrayColor forState:UIControlStateNormal];
        [closeBtn addTarget:self action:@selector(onClose) forControlEvents:UIControlEventTouchUpInside];

        [panel addSubview:title];
        [panel addSubview:sField];
        [panel addSubview:searchBtn];
        [panel addSubview:sResult];
        [panel addSubview:closeBtn];
        [vc.view addSubview:panel];

        sWindow.rootViewController = vc;
        sWindow.hidden = NO;
        [sWindow makeKeyAndVisible];
    });
}

+ (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        sWindow.hidden = YES;
    });
}

+ (void)onSearch {
    NSString *kw = [sField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
    if (kw.length == 0) {
        sResult.text = @"请输入关键词。";
        return;
    }
    sResult.text = @"扫描中，请稍候…";
    [sField resignFirstResponder];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *report = [ClassDumpSearch generateReportAndCopyToPasteboard:kw maxResults:300];
        dispatch_async(dispatch_get_main_queue(), ^{
            sResult.text = [report stringByAppendingString:@"\n\n（已复制到剪贴板）"];
        });
    });
}

+ (void)onClose {
    [self hide];
}

@end
