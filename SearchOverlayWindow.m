#import "SearchOverlayWindow.h"
#import "ClassDumpSearcher.h"

#pragma mark - SearchOverlayWindow

@interface SearchOverlayWindow () <UITextFieldDelegate>
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UITextView *resultView;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation SearchOverlayWindow

static SearchOverlayWindow *_sharedOverlay = nil;

#pragma mark - 生命周期

+ (void)show {
    if (_sharedOverlay) {
        [_sharedOverlay setHidden:NO];
        [_sharedOverlay makeKeyAndVisible];
        return;
    }

    UIWindowScene *scene = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        if (!scene) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) {
                    scene = (UIWindowScene *)s;
                    break;
                }
            }
        }
    }

    CGRect screenBounds = [UIScreen mainScreen].bounds;
    SearchOverlayWindow *win;

    if (@available(iOS 13.0, *)) {
        if (scene) {
            win = [[SearchOverlayWindow alloc] initWithWindowScene:scene];
        } else {
            win = [[SearchOverlayWindow alloc] initWithFrame:screenBounds];
        }
    } else {
        win = [[SearchOverlayWindow alloc] initWithFrame:screenBounds];
    }

    // 窗口层级设到最高，确保覆盖所有界面
    win.windowLevel = 2100.0;
    win.backgroundColor = [UIColor clearColor];
    [win setupUI];

    _sharedOverlay = win;
    [win makeKeyAndVisible];
}

+ (void)dismiss {
    if (_sharedOverlay) {
        [_sharedOverlay setHidden:YES];
        [_sharedOverlay resignKeyWindow];
        _sharedOverlay = nil;
    }
}

#pragma mark - UI 构建

- (void)setupUI {
    CGFloat panelW = MIN([UIScreen mainScreen].bounds.size.width - 40, 500);
    CGFloat panelH = MIN([UIScreen mainScreen].bounds.size.height - 100, 600);
    CGFloat originX = ([UIScreen mainScreen].bounds.size.width - panelW) / 2;
    CGFloat originY = 60;

    // 背景遮罩
    UIButton *bgDismiss = [UIButton buttonWithType:UIButtonTypeCustom];
    bgDismiss.frame = self.bounds;
    bgDismiss.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.35];
    [bgDismiss addTarget:self action:@selector(dismissTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:bgDismiss];

    // 面板容器
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(originX, originY, panelW, panelH)];
    panel.tag = 9999;
    panel.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.95];
    panel.layer.cornerRadius = 16;
    panel.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1].CGColor;
    panel.layer.borderWidth = 0.5;
    panel.clipsToBounds = YES;
    [self addSubview:panel];
    self.panelView = panel;

    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, panelW - 80, 24)];
    titleLabel.text = @"🔍 Runtime Class Dump";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [panel addSubview:titleLabel];

    // 关闭按钮
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(panelW - 40, 8, 32, 32);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [closeBtn addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:closeBtn];
    self.closeButton = closeBtn;

    // 搜索输入框
    CGFloat y = 50;
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, panelW - 100, 36)];
    textField.placeholder = @"输入关键词（如 vip, token）";
    textField.textColor = [UIColor whiteColor];
    textField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    textField.layer.cornerRadius = 8;
    textField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 0)];
    textField.leftViewMode = UITextFieldViewModeAlways;
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.returnKeyType = UIReturnKeySearch;
    textField.font = [UIFont systemFontOfSize:15];
    textField.delegate = self;
    [panel addSubview:textField];
    self.searchField = textField;

    // 搜索按钮
    UIButton *searchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    searchBtn.frame = CGRectMake(panelW - 76, y, 60, 36);
    [searchBtn setTitle:@"搜索" forState:UIControlStateNormal];
    searchBtn.backgroundColor = [UIColor systemBlueColor];
    searchBtn.tintColor = [UIColor whiteColor];
    searchBtn.layer.cornerRadius = 8;
    searchBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [searchBtn addTarget:self action:@selector(searchTapped) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:searchBtn];
    self.searchButton = searchBtn;

    // 加载指示器
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.center = CGPointMake(panelW / 2, panelH / 2);
    spinner.hidesWhenStopped = YES;
    [panel addSubview:spinner];
    self.spinner = spinner;

    // 结果显示区域
    CGFloat resultY = y + 48;
    CGFloat resultH = panelH - resultY - 16;
    UITextView *resultView = [[UITextView alloc] initWithFrame:CGRectMake(8, resultY, panelW - 16, resultH)];
    resultView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    resultView.textColor = [UIColor colorWithRed:0.4 green:0.9 blue:0.4 alpha:1];
    resultView.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12];
    resultView.editable = NO;
    resultView.layer.cornerRadius = 8;
    resultView.contentInset = UIEdgeInsetsMake(8, 8, 8, 8);
    [panel addSubview:resultView];
    self.resultView = resultView;

    self.resultView.text = @"输入关键词后点击搜索，或按回车键。\n\n"
                           "提示：搜索结果会自动复制到剪贴板。\n"
                           "支持的 API 版本: iOS 14+";
}

#pragma mark - 事件处理

- (void)searchTapped {
    [self.searchField resignFirstResponder];
    NSString *keyword = self.searchField.text;
    if (keyword.length == 0) {
        self.resultView.text = @"⚠️ 请输入搜索关键词";
        return;
    }

    self.resultView.text = @"";
    [self.spinner startAnimating];
    self.searchButton.enabled = NO;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *report = [ClassDumpSearcher searchAndCopyWithKeyword:keyword];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.searchButton.enabled = YES;
            self.resultView.text = report;
            [self.resultView scrollRangeToVisible:NSMakeRange(0, 0)];

            UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 36)];
            toast.center = CGPointMake(self.panelView.frame.size.width / 2, self.panelView.frame.size.height / 2);
            toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
            toast.textColor = [UIColor whiteColor];
            toast.textAlignment = NSTextAlignmentCenter;
            toast.text = @"✅ 已复制到剪贴板";
            toast.layer.cornerRadius = 8;
            toast.clipsToBounds = YES;
            toast.font = [UIFont systemFontOfSize:14];
            [self.panelView addSubview:toast];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [toast removeFromSuperview];
            });
        });
    });
}

- (void)closeTapped {
    [SearchOverlayWindow dismiss];
}

- (void)dismissTapped {
    [self.searchField resignFirstResponder];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self searchTapped];
    return YES;
}

@end
