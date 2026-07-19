#import "SearchOverlayWindow.h"
#import "ClassDumpSearcher.h"
#import "MethodHacker.h"
#import "UserDefaultsEditor.h"
#import "ProbeEngine.h"
#import <objc/runtime.h>

typedef NS_ENUM(NSUInteger, OverlayTab) {
    OverlayTabSearch   = 0,
    OverlayTabHooks    = 1,
    OverlayTabProbe    = 2,
    OverlayTabDefaults = 3,
    OverlayTabLogs     = 4,
    OverlayTabCount    = 5
};

@interface SearchOverlayWindow () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UIView *contentArea;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, assign) OverlayTab currentTab;
@property (nonatomic, strong) NSMutableArray<UIButton *> *tabButtons;
// 搜索
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UITextView *resultView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
// Hook
@property (nonatomic, strong) UITableView *hooksTable;
@property (nonatomic, strong) NSArray<ActiveHook *> *hooksList;
// 探测
@property (nonatomic, strong) UIButton *probeButton;
@property (nonatomic, strong) UIProgressView *probeProgress;
@property (nonatomic, strong) UILabel *probeStatusLabel;
@property (nonatomic, strong) UITextView *probeResultView;
@property (nonatomic, strong) UIActivityIndicatorView *probeSpinner;
// 默认值
@property (nonatomic, strong) UITextField *defaultsSearchField;
@property (nonatomic, strong) UITableView *defaultsTable;
@property (nonatomic, strong) NSDictionary *defaultsData;
@property (nonatomic, strong) NSArray *defaultsKeys;
// 日志
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) UIButton *clearLogButton;
@end

@implementation SearchOverlayWindow
static SearchOverlayWindow *_sharedOverlay = nil;

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
                scene = (UIWindowScene *)s; break;
            }
        }
        if (!scene) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
            }
        }
    }
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    SearchOverlayWindow *win;
    if (@available(iOS 13.0, *)) {
        win = scene ? [[SearchOverlayWindow alloc] initWithWindowScene:scene] : [[SearchOverlayWindow alloc] initWithFrame:screenBounds];
    } else {
        win = [[SearchOverlayWindow alloc] initWithFrame:screenBounds];
    }
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

- (void)setupUI {
    CGFloat panelW = MIN([UIScreen mainScreen].bounds.size.width - 40, 520);
    CGFloat panelH = MIN([UIScreen mainScreen].bounds.size.height - 80, 700);
    CGFloat ox = ([UIScreen mainScreen].bounds.size.width - panelW) / 2;
    CGFloat oy = 40;

    // 背景
    UIButton *bg = [UIButton buttonWithType:UIButtonTypeCustom];
    bg.frame = self.bounds;
    bg.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.35];
    [bg addTarget:self action:@selector(dismissTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:bg];

    // 面板
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(ox, oy, panelW, panelH)];
    panel.tag = 9999;
    panel.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.96];
    panel.layer.cornerRadius = 16;
    panel.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1].CGColor;
    panel.layer.borderWidth = 0.5;
    panel.clipsToBounds = YES;
    [self addSubview:panel];
    self.panelView = panel;

    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, panelW - 80, 28)];
    title.text = @"🔧 Runtime 工具箱";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:16];
    [panel addSubview:title];

    // 关闭
    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.closeButton.frame = CGRectMake(panelW - 40, 6, 32, 32);
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:self.closeButton];

    // 内容区域
    CGFloat contentY = 42;
    CGFloat contentH = panelH - contentY - 44;
    self.contentArea = [[UIView alloc] initWithFrame:CGRectMake(0, contentY, panelW, contentH)];
    self.contentArea.backgroundColor = [UIColor clearColor];
    [panel addSubview:self.contentArea];

    // 底部 Tab 栏 - 5 个
    CGFloat tabY = panelH - 42;
    UIView *tabBar = [[UIView alloc] initWithFrame:CGRectMake(0, tabY, panelW, 42)];
    tabBar.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1];
    tabBar.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1].CGColor;
    tabBar.layer.borderWidth = 0.5;
    [panel addSubview:tabBar];

    self.tabButtons = [NSMutableArray array];
    NSArray *tabTitles = @[@"🔍", @"🪝", @"📡", @"⚙️", @"📋"];
    NSArray *tabLabels = @[@"搜索", @"Hook", @"探测", @"默认值", @"日志"];
    CGFloat tw = panelW / OverlayTabCount;
    for (int i = 0; i < OverlayTabCount; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(i * tw, 0, tw, 42);
        [b setTitle:tabTitles[i] forState:UIControlStateNormal];
        [b setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:16];
        b.tag = i;
        // 添加小标签
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 26, tw, 14)];
        lbl.text = tabLabels[i];
        lbl.textColor = [UIColor grayColor];
        lbl.font = [UIFont systemFontOfSize:9];
        lbl.textAlignment = NSTextAlignmentCenter;
        [b addSubview:lbl];
        [b addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [tabBar addSubview:b];
        [self.tabButtons addObject:b];
    }

    [self buildSearchPanel];
    [self buildHooksPanel];
    [self buildProbePanel];
    [self buildDefaultsPanel];
    [self buildLogsPanel];
    [self switchToTab:OverlayTabSearch];

    // 监听 Hook 日志更新
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(hookLogDidUpdate:)
                                                 name:HookLogDidUpdateNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Tab

- (void)tabTapped:(UIButton *)s { [self switchToTab:(OverlayTab)s.tag]; }

- (void)switchToTab:(OverlayTab)tab {
    self.currentTab = tab;
    for (UIView *v in self.contentArea.subviews) v.hidden = YES;
    UIColor *activeColor = [UIColor colorWithRed:0.25 green:0.45 blue:0.85 alpha:1];
    for (UIButton *b in self.tabButtons) {
        b.backgroundColor = [UIColor clearColor];
        b.tintColor = [UIColor grayColor];
        for (UIView *sv in b.subviews) {
            if ([sv isKindOfClass:[UILabel class]]) {
                ((UILabel *)sv).textColor = [UIColor grayColor];
            }
        }
    }
    UIButton *activeBtn = self.tabButtons[tab];
    activeBtn.backgroundColor = activeColor;
    activeBtn.tintColor = [UIColor whiteColor];
    for (UIView *sv in activeBtn.subviews) {
        if ([sv isKindOfClass:[UILabel class]]) {
            ((UILabel *)sv).textColor = [UIColor whiteColor];
        }
    }

    UIView *tv = [self.contentArea viewWithTag:(1001 + tab)];
    tv.hidden = NO;

    if (tab == OverlayTabHooks) [self refreshHooksList];
    else if (tab == OverlayTabDefaults) [self refreshDefaults];
    else if (tab == OverlayTabLogs) [self refreshLogDisplay];
}

#pragma mark - 搜索面板

- (void)buildSearchPanel {
    CGFloat w = self.contentArea.frame.size.width, h = self.contentArea.frame.size.height;
    UIView *v = [[UIView alloc] initWithFrame:self.contentArea.bounds]; v.tag = 1001;
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(12, 8, w-90, 34)];
    tf.placeholder = @"关键词 (vip, token...)"; tf.textColor = [UIColor whiteColor];
    tf.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1]; tf.layer.cornerRadius = 8;
    tf.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 0)]; tf.leftViewMode = UITextFieldViewModeAlways;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.autocorrectionType = UITextAutocorrectionTypeNo; tf.returnKeyType = UIReturnKeySearch;
    tf.font = [UIFont systemFontOfSize:14]; tf.delegate = self;
    [v addSubview:tf]; self.searchField = tf;

    UIButton *sb = [UIButton buttonWithType:UIButtonTypeSystem];
    sb.frame = CGRectMake(w-74, 8, 62, 34); [sb setTitle:@"搜索" forState:UIControlStateNormal];
    [sb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    sb.backgroundColor = [UIColor systemBlueColor]; sb.layer.cornerRadius = 8;
    sb.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [sb addTarget:self action:@selector(searchTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:sb]; self.searchButton = sb;

    UIActivityIndicatorView *sp = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    sp.center = CGPointMake(w/2, h/2); sp.hidesWhenStopped = YES;
    [v addSubview:sp]; self.spinner = sp;

    UITextView *tv = [[UITextView alloc] initWithFrame:CGRectMake(6, 48, w-12, h-54)];
    tv.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    tv.textColor = [UIColor colorWithRed:0.4 green:0.9 blue:0.4 alpha:1];
    tv.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    tv.editable = NO; tv.layer.cornerRadius = 8;
    tv.contentInset = UIEdgeInsetsMake(8, 8, 8, 8);
    tv.text = @"输入关键词，点击搜索。\n支持: vip / token / user / pay ...";
    [v addSubview:tv]; self.resultView = tv;
    [self.contentArea addSubview:v];
}

- (void)searchTapped {
    [self.searchField resignFirstResponder];
    NSString *kw = self.searchField.text;
    if (kw.length == 0) { self.resultView.text = @"⚠️ 请输入关键词"; return; }
    self.resultView.text = @""; [self.spinner startAnimating]; self.searchButton.enabled = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *r = [ClassDumpSearcher searchAndCopyWithKeyword:kw];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating]; self.searchButton.enabled = YES;
            self.resultView.text = r;
            [self.resultView scrollRangeToVisible:NSMakeRange(0, 0)];
            [self showToast:@"✅ 已复制到剪贴板"];
        });
    });
}

#pragma mark - Hook 面板

- (void)buildHooksPanel {
    CGFloat w = self.contentArea.frame.size.width, h = self.contentArea.frame.size.height;
    UIView *view = [[UIView alloc] initWithFrame:self.contentArea.bounds]; view.tag = 1002;

    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    addBtn.frame = CGRectMake(12, 4, w-24, 28);
    [addBtn setTitle:@"➕ 添加 Hook" forState:UIControlStateNormal];
    [addBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    addBtn.backgroundColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.2 alpha:1];
    addBtn.layer.cornerRadius = 6; addBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [addBtn addTarget:self action:@selector(addHookTapped) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:addBtn];

    CGFloat by = 36, bw = (w-36)/3;
    NSArray *tpl = @[@[@"🦸 VIP", @"VIPManager", @"isVIPMember"],
                     @[@"🦸 VIP", @"UserInfo", @"isVIP"],
                     @[@"🦸 VIP", @"SettingsManager", @"isPremium"],
                     @[@"🚫 广告", @"AdManager", @"shouldShowAd"],
                     @[@"🚫 广告", @"ADManager", @"isAd"],
                     @[@"🔓 解锁", @"PaywallManager", @"isLocked"]];
    for (int i = 0; i < (int)tpl.count; i++) {
        NSArray *t = tpl[i];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(12+(i%3)*(bw+6), by+(i/3)*28, bw, 24);
        [b setTitle:t[0] forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.backgroundColor = [UIColor colorWithRed:0.25 green:0.35 blue:0.55 alpha:1];
        b.layer.cornerRadius = 5; b.titleLabel.font = [UIFont systemFontOfSize:10];
        objc_setAssociatedObject(b, "_hook_cls", t[1], OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(b, "_hook_sel", t[2], OBJC_ASSOCIATION_RETAIN);
        [b addTarget:self action:@selector(quickHookTapped:) forControlEvents:UIControlEventTouchUpInside];
        [view addSubview:b];
    }

    CGFloat tipY = by + ((int)tpl.count/3 + 1)*28 + 2;
    UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(12, tipY, w-24, 16)];
    tip.text = @"活跃 Hook（左滑取消）"; tip.textColor = [UIColor lightGrayColor];
    tip.font = [UIFont systemFontOfSize:10];
    [view addSubview:tip];

    CGFloat tY = tipY + 18;
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, tY, w, h-tY) style:UITableViewStylePlain];
    table.backgroundColor = [UIColor clearColor]; table.dataSource = self; table.delegate = self;
    table.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    table.separatorColor = [UIColor colorWithWhite:0.3 alpha:0.5];
    [view addSubview:table]; self.hooksTable = table;
    [self.contentArea addSubview:view];
}

- (void)quickHookTapped:(UIButton *)s {
    NSString *c = objc_getAssociatedObject(s, "_hook_cls"), *sel = objc_getAssociatedObject(s, "_hook_sel");
    if (!c || !sel) return;
    BOOL rYES = YES;
    for (NSString *kw in @[@"Ad",@"ad",@"Locked",@"locked",@"Banner",@"banner"])
        if ([sel containsString:kw]) { rYES = NO; break; }
    BOOL ok = [MethodHacker hookMethodWithClass:c methodName:sel isClassMethod:NO returnType:@"BOOL" value:@(rYES)];
    [self showToast:ok ? [NSString stringWithFormat:@"✅ %@.%@ → %@",c,sel,rYES?@"YES":@"NO"] : [NSString stringWithFormat:@"❌ %@.%@ 未找到",c,sel]];
    if (ok) [self refreshHooksList];
}

- (void)refreshHooksList { self.hooksList = [MethodHacker activeHooks]; [self.hooksTable reloadData]; }

- (void)addHookTapped {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"添加 Hook" message:@"输入类名与方法名" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder = @"类名"; t.autocapitalizationType = UITextAutocapitalizationTypeNone; }];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder = @"方法名"; t.autocapitalizationType = UITextAutocapitalizationTypeNone; }];
    __block NSString *st = @"BOOL"; __block int ti = 0;
    [a addAction:[UIAlertAction actionWithTitle:@"类型: BOOL (切换)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        ti = (ti+1)%5;
        st = @[@"BOOL",@"id",@"NSInteger",@"double",@"void"][ti];
        [self addHookTapped];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"确定 Hook" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
        NSString *c = [a.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSString *s = [a.textFields[1].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (c.length == 0 || s.length == 0) { [self showToast:@"⚠️ 不能为空"]; return; }
        id val = @YES;
        if ([st isEqualToString:@"BOOL"]) val = @YES;
        else if ([st isEqualToString:@"id"]) val = @"(nil)";
        else if ([st isEqualToString:@"NSInteger"]) val = @0;
        else if ([st isEqualToString:@"double"]) val = @0.0;
        else val = nil;
        BOOL ok = [MethodHacker hookMethodWithClass:c methodName:s isClassMethod:NO returnType:st value:val];
        [self showToast:ok ? [NSString stringWithFormat:@"✅ Hook %@.%@",c,s] : [NSString stringWithFormat:@"❌ Hook 失败: %@.%@",c,s]];
        if (ok) [self refreshHooksList];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [[self viewControllerForPresent] presentViewController:a animated:YES completion:nil];
}

#pragma mark - 探测面板

- (void)buildProbePanel {
    CGFloat w = self.contentArea.frame.size.width, h = self.contentArea.frame.size.height;
    UIView *v = [[UIView alloc] initWithFrame:self.contentArea.bounds]; v.tag = 1003;

    self.probeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.probeButton.frame = CGRectMake(12, 6, 80, 30);
    [self.probeButton setTitle:@"▶️ 开始探测" forState:UIControlStateNormal];
    [self.probeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.probeButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.3 alpha:1];
    self.probeButton.layer.cornerRadius = 6;
    self.probeButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [self.probeButton addTarget:self action:@selector(probeTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:self.probeButton];

    // VIP 快捷按钮
    UIButton *vipBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    vipBtn.frame = CGRectMake(98, 6, 70, 30);
    [vipBtn setTitle:@"🦸 VIP分析" forState:UIControlStateNormal];
    [vipBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    vipBtn.backgroundColor = [UIColor colorWithRed:0.6 green:0.3 blue:0.1 alpha:1];
    vipBtn.layer.cornerRadius = 6;
    vipBtn.titleLabel.font = [UIFont boldSystemFontOfSize:10];
    [vipBtn addTarget:self action:@selector(probeVIPTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:vipBtn];

    self.probeProgress = [[UIProgressView alloc] initWithFrame:CGRectMake(174, 12, w-186, 4)];
    self.probeProgress.progressTintColor = [UIColor systemGreenColor];
    self.probeProgress.hidden = YES;
    [v addSubview:self.probeProgress];

    self.probeStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(174, 18, w-186, 18)];
    self.probeStatusLabel.textColor = [UIColor lightGrayColor];
    self.probeStatusLabel.font = [UIFont systemFontOfSize:10];
    self.probeStatusLabel.hidden = YES;
    [v addSubview:self.probeStatusLabel];

    self.probeSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.probeSpinner.center = CGPointMake(w/2, h/2);
    self.probeSpinner.hidesWhenStopped = YES;
    [v addSubview:self.probeSpinner];

    self.probeResultView = [[UITextView alloc] initWithFrame:CGRectMake(6, 42, w-12, h-48)];
    self.probeResultView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    self.probeResultView.textColor = [UIColor colorWithRed:0.4 green:0.9 blue:0.4 alpha:1];
    self.probeResultView.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    self.probeResultView.editable = NO; self.probeResultView.layer.cornerRadius = 8;
    self.probeResultView.contentInset = UIEdgeInsetsMake(6, 6, 6, 6);
    self.probeResultView.text = @"点击「开始探测」自动扫描所有类的关键词方法。\n也可点击「VIP分析」专项扫描 VIP 相关方法。";
    [v addSubview:self.probeResultView];
    [self.contentArea addSubview:v];
}

- (void)probeTapped {
    self.probeButton.enabled = NO;
    self.probeProgress.hidden = NO;
    self.probeProgress.progress = 0;
    self.probeStatusLabel.hidden = NO;
    self.probeStatusLabel.text = @"准备中...";
    self.probeResultView.text = @"";
    [self.probeSpinner startAnimating];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *results = [ProbeEngine runProbeWithMaxClasses:300 progress:^(float progress, NSString *currentClass) {
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.probeProgress.progress = progress;
                weakSelf.probeStatusLabel.text = [NSString stringWithFormat:@"%.0f%% %@", progress*100, currentClass];
            });
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.probeSpinner stopAnimating];
            weakSelf.probeButton.enabled = YES;
            weakSelf.probeProgress.hidden = YES;
            weakSelf.probeStatusLabel.hidden = YES;
            NSString *report = [ProbeEngine formatReport:results];
            weakSelf.probeResultView.text = report;
            [UIPasteboard generalPasteboard].string = report;
            [weakSelf showToast:[NSString stringWithFormat:@"✅ 发现 %lu 个匹配项，已复制", (unsigned long)results.count]];
        });
    });
}

- (void)probeVIPTapped {
    self.probeButton.enabled = NO;
    self.probeResultView.text = @"VIP 分析中...";
    [self.probeSpinner startAnimating];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *results = [ProbeEngine runProbeWithMaxClasses:300 progress:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.probeSpinner stopAnimating];
            weakSelf.probeButton.enabled = YES;
            NSString *report = [ProbeEngine formatVIPReport:results];
            weakSelf.probeResultView.text = report;
            [UIPasteboard generalPasteboard].string = report;
            [weakSelf showToast:[NSString stringWithFormat:@"✅ VIP 分析完成"]];
        });
    });
}

#pragma mark - 默认值面板

- (void)buildDefaultsPanel {
    CGFloat w = self.contentArea.frame.size.width, h = self.contentArea.frame.size.height;
    UIView *view = [[UIView alloc] initWithFrame:self.contentArea.bounds]; view.tag = 1004;

    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(12, 8, w-24, 32)];
    tf.placeholder = @"搜索键名"; tf.textColor = [UIColor whiteColor];
    tf.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1]; tf.layer.cornerRadius = 8;
    tf.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 0)]; tf.leftViewMode = UITextFieldViewModeAlways;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.autocorrectionType = UITextAutocorrectionTypeNo; tf.returnKeyType = UIReturnKeySearch;
    tf.font = [UIFont systemFontOfSize:13]; tf.delegate = self; tf.tag = 2001;
    [tf addTarget:self action:@selector(defaultsSearchChanged) forControlEvents:UIControlEventEditingChanged];
    [view addSubview:tf]; self.defaultsSearchField = tf;

    UIButton *copyB = [UIButton buttonWithType:UIButtonTypeSystem];
    copyB.frame = CGRectMake(w-56, 42, 44, 24);
    [copyB setTitle:@"📋" forState:UIControlStateNormal];
    [copyB setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyB.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1];
    copyB.layer.cornerRadius = 6; copyB.titleLabel.font = [UIFont systemFontOfSize:12];
    [copyB addTarget:self action:@selector(copyDefaultsTapped) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:copyB];

    UIButton *refB = [UIButton buttonWithType:UIButtonTypeSystem];
    refB.frame = CGRectMake(12, 42, 44, 24);
    [refB setTitle:@"🔄" forState:UIControlStateNormal];
    [refB setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    refB.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1];
    refB.layer.cornerRadius = 6; refB.titleLabel.font = [UIFont systemFontOfSize:12];
    [refB addTarget:self action:@selector(refreshDefaults) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:refB];

    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 70, w, h-70) style:UITableViewStylePlain];
    table.backgroundColor = [UIColor clearColor]; table.dataSource = self; table.delegate = self;
    table.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    table.separatorColor = [UIColor colorWithWhite:0.3 alpha:0.5]; table.tag = 3001;
    [view addSubview:table]; self.defaultsTable = table;
    [self.contentArea addSubview:view];
}

- (void)refreshDefaults {
    NSString *kw = self.defaultsSearchField.text;
    self.defaultsData = kw.length > 0 ? [UserDefaultsEditor searchDefaultsWithKeyword:kw] : [UserDefaultsEditor allDefaults];
    self.defaultsKeys = [[self.defaultsData allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    [self.defaultsTable reloadData];
}
- (void)defaultsSearchChanged { [self refreshDefaults]; }
- (void)copyDefaultsTapped {
    NSString *r = [UserDefaultsEditor formatReport:self.defaultsData];
    [UIPasteboard generalPasteboard].string = r; [self showToast:@"✅ 已复制"];
}

#pragma mark - 日志面板

- (void)buildLogsPanel {
    CGFloat w = self.contentArea.frame.size.width, h = self.contentArea.frame.size.height;
    UIView *v = [[UIView alloc] initWithFrame:self.contentArea.bounds]; v.tag = 1005;

    self.clearLogButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clearLogButton.frame = CGRectMake(w-66, 4, 54, 24);
    [self.clearLogButton setTitle:@"🗑 清除" forState:UIControlStateNormal];
    [self.clearLogButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.clearLogButton.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1];
    self.clearLogButton.layer.cornerRadius = 5;
    self.clearLogButton.titleLabel.font = [UIFont systemFontOfSize:10];
    [self.clearLogButton addTarget:self action:@selector(clearLogTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:self.clearLogButton];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 6, w-80, 22)];
    lbl.text = @"📋 Hook 调用日志（使用 Log Hook 类型记录）";
    lbl.textColor = [UIColor lightGrayColor];
    lbl.font = [UIFont systemFontOfSize:11];
    [v addSubview:lbl];

    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(6, 32, w-12, h-38)];
    self.logView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    self.logView.textColor = [UIColor colorWithRed:0.6 green:0.8 blue:1.0 alpha:1];
    self.logView.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    self.logView.editable = NO; self.logView.layer.cornerRadius = 8;
    self.logView.contentInset = UIEdgeInsetsMake(6, 6, 6, 6);
    self.logView.text = @"使用 Log Hook 类型后，被 Hook 方法的调用记录会显示在这里。";
    [v addSubview:self.logView];
    [self.contentArea addSubview:v];
}

- (void)refreshLogDisplay {
    NSArray *logs = [MethodHacker hookLogs];
    if (logs.count == 0) {
        self.logView.text = @"暂无 Hook 调用记录。\n\n在 Hook 面板添加时选择 Log 类型，\n被 Hook 的方法被调用时会记录在此。";
    } else {
        self.logView.text = [[logs reverseObjectEnumerator] allObjects].count > 0 ?
            [[[logs reverseObjectEnumerator] allObjects] componentsJoinedByString:@"\n"] : @"";
    }
}

- (void)hookLogDidUpdate:(NSNotification *)note {
    if (self.currentTab == OverlayTabLogs) {
        [self refreshLogDisplay];
    }
}

- (void)clearLogTapped {
    [MethodHacker clearLogs];
    [self refreshLogDisplay];
    [self showToast:@"✅ 日志已清除"];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)section {
    if (t == self.hooksTable) return MAX(self.hooksList.count, 1);
    if (t == self.defaultsTable) return MAX(self.defaultsKeys.count, 1);
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:@"cell"];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
        c.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
        c.textLabel.textColor = [UIColor whiteColor];
        c.detailTextLabel.textColor = [UIColor lightGrayColor];
        c.textLabel.font = [UIFont systemFontOfSize:12];
        c.detailTextLabel.font = [UIFont systemFontOfSize:10];
        c.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    if (t == self.hooksTable) {
        if (self.hooksList.count == 0) {
            c.textLabel.text = @"暂无活跃 Hook";
            c.detailTextLabel.text = @"点击上方按钮添加";
        } else {
            ActiveHook *h = self.hooksList[ip.row];
            NSString *typeStr = @"";
            switch (h.hookType) {
                case HookTypeReturn: typeStr = @"🔒"; break;
                case HookTypeLog: typeStr = @"📝"; break;
                case HookTypeBlock: typeStr = @"📦"; break;
                case HookTypeSwizzle: typeStr = @"🔄"; break;
                case HookTypeKVC: typeStr = @"✏️"; break;
            }
            c.textLabel.text = [NSString stringWithFormat:@"%@ %@.%@", typeStr, h.className, h.methodName];
            NSString *extra = h.hookType == HookTypeLog ? [NSString stringWithFormat:@" (调用%lu次)", (unsigned long)h.callCount] : @"";
            c.detailTextLabel.text = [NSString stringWithFormat:@"→ %@%@", h.returnValue ?: (h.hookType==HookTypeLog?@"Log":@"void"), extra];
        }
    } else if (t == self.defaultsTable) {
        if (self.defaultsKeys.count == 0) {
            c.textLabel.text = @"无数据";
            c.detailTextLabel.text = @"没有找到 UserDefaults";
        } else {
            NSString *k = self.defaultsKeys[ip.row];
            id v = self.defaultsData[k];
            c.textLabel.text = k;
            c.detailTextLabel.text = [v isKindOfClass:NSData.class] ?
                [NSString stringWithFormat:@"<Data: %lu bytes>",(unsigned long)[(NSData*)v length]] :
                [NSString stringWithFormat:@"%@",v];
        }
    }
    return c;
}

- (BOOL)tableView:(UITableView *)t canEditRowAtIndexPath:(NSIndexPath *)ip {
    return (t == self.hooksTable && self.hooksList.count > 0) ||
           (t == self.defaultsTable && self.defaultsKeys.count > 0);
}

- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)ed forRowAtIndexPath:(NSIndexPath *)ip {
    if (t == self.hooksTable) {
        [MethodHacker unhook:self.hooksList[ip.row]];
        [self refreshHooksList];
    } else {
        [UserDefaultsEditor removeKey:self.defaultsKeys[ip.row]];
        [self refreshDefaults];
    }
}

- (NSString *)tableView:(UITableView *)t titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)ip {
    return t == self.hooksTable ? @"取消Hook" : @"删除";
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    if (t == self.defaultsTable && self.defaultsKeys.count > 0)
        [self showEditDefaultDialog:self.defaultsKeys[ip.row] currentValue:self.defaultsData[self.defaultsKeys[ip.row]]];
}

- (void)showEditDefaultDialog:(NSString *)key currentValue:(id)value {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"编辑: %@",key]
                                                               message:@"输入新值" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.text = [NSString stringWithFormat:@"%@",value?:@""]; }];
    [a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        NSString *nv = a.textFields[0].text;
        if (nv) { [UserDefaultsEditor setValue:nv forKey:key]; [self refreshDefaults]; [self showToast:[NSString stringWithFormat:@"✅ %@ = %@",key,nv]]; }
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
        [UserDefaultsEditor removeKey:key]; [self refreshDefaults]; [self showToast:[NSString stringWithFormat:@"🗑️ 已删除 %@",key]];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [[self viewControllerForPresent] presentViewController:a animated:YES completion:nil];
}

#pragma mark - 辅助

- (void)showToast:(NSString *)msg {
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
    t.center = CGPointMake(self.panelView.frame.size.width/2, self.panelView.frame.size.height/2-20);
    t.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85]; t.textColor = [UIColor whiteColor];
    t.textAlignment = NSTextAlignmentCenter; t.text = msg; t.layer.cornerRadius = 8;
    t.clipsToBounds = YES; t.font = [UIFont systemFontOfSize:12];
    [self.panelView addSubview:t];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [t removeFromSuperview]; });
}

- (UIViewController *)viewControllerForPresent {
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *w in [(UIWindowScene *)s windows]) {
                    UIViewController *r = w.rootViewController;
                    if (r) { while (r.presentedViewController) r = r.presentedViewController; return r; }
                }
            }
        }
    }
    UIViewController *r = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (r.presentedViewController) r = r.presentedViewController;
    return r;
}

- (void)closeTapped { [SearchOverlayWindow dismiss]; }
- (void)dismissTapped { [self.searchField resignFirstResponder]; [self.defaultsSearchField resignFirstResponder]; }

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)t {
    if (t == self.searchField) [self searchTapped];
    else if (t.tag == 2001) [self refreshDefaults];
    [t resignFirstResponder]; return YES;
}
@end
