#import "SearchOverlayWindow.h"
#import "ClassDumpSearcher.h"
#import "MethodHacker.h"
#import "UserDefaultsEditor.h"

#pragma mark - 面板 Tab 类型

typedef NS_ENUM(NSUInteger, OverlayTab) {
    OverlayTabSearch   = 0,
    OverlayTabHooks    = 1,
    OverlayTabDefaults = 2
};

#pragma mark - SearchOverlayWindow

@interface SearchOverlayWindow () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>
// 通用
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UIView *contentArea;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, assign) OverlayTab currentTab;

// Tab 按钮
@property (nonatomic, strong) UIButton *tabSearchBtn;
@property (nonatomic, strong) UIButton *tabHooksBtn;
@property (nonatomic, strong) UIButton *tabDefaultsBtn;

// ── 搜索面板 ──
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UITextView *resultView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

// ── Hooks 面板 ──
@property (nonatomic, strong) UITableView *hooksTable;
@property (nonatomic, strong) UIButton *addHookButton;
@property (nonatomic, strong) NSArray<ActiveHook *> *hooksList;

// ── Defaults 面板 ──
@property (nonatomic, strong) UITextField *defaultsSearchField;
@property (nonatomic, strong) UITableView *defaultsTable;
@property (nonatomic, strong) NSDictionary *defaultsData;
@property (nonatomic, strong) NSArray *defaultsKeys;

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
    CGFloat panelW = MIN([UIScreen mainScreen].bounds.size.width - 40, 520);
    CGFloat panelH = MIN([UIScreen mainScreen].bounds.size.height - 80, 680);
    CGFloat originX = ([UIScreen mainScreen].bounds.size.width - panelW) / 2;
    CGFloat originY = 50;

    // 背景遮罩
    UIButton *bg = [UIButton buttonWithType:UIButtonTypeCustom];
    bg.frame = self.bounds;
    bg.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.35];
    [bg addTarget:self action:@selector(dismissTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:bg];

    // 面板
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(originX, originY, panelW, panelH)];
    panel.tag = 9999;
    panel.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.96];
    panel.layer.cornerRadius = 16;
    panel.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1].CGColor;
    panel.layer.borderWidth = 0.5;
    panel.clipsToBounds = YES;
    [self addSubview:panel];
    self.panelView = panel;

    // ── 顶栏 ──
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, panelW - 80, 28)];
    title.text = @"🔍 ClassDump + Hooks";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:16];
    [panel addSubview:title];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.closeButton.frame = CGRectMake(panelW - 40, 6, 32, 32);
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:self.closeButton];

    // ── 内容区 ──
    CGFloat contentY = 44;
    CGFloat contentH = panelH - contentY - 50;
    self.contentArea = [[UIView alloc] initWithFrame:CGRectMake(0, contentY, panelW, contentH)];
    self.contentArea.backgroundColor = [UIColor clearColor];
    [panel addSubview:self.contentArea];

    // ── 底部 Tab 栏 ──
    CGFloat tabY = panelH - 44;
    UIView *tabBar = [[UIView alloc] initWithFrame:CGRectMake(0, tabY, panelW, 44)];
    tabBar.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1];
    tabBar.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1].CGColor;
    tabBar.layer.borderWidth = 0.5;
    [panel addSubview:tabBar];

    CGFloat tabW = panelW / 3;
    self.tabSearchBtn = [self tabButtonWithFrame:CGRectMake(0, 0, tabW, 44) title:@"🔍 搜索" tag:OverlayTabSearch];
    self.tabHooksBtn  = [self tabButtonWithFrame:CGRectMake(tabW, 0, tabW, 44) title:@"🪝 Hook" tag:OverlayTabHooks];
    self.tabDefaultsBtn = [self tabButtonWithFrame:CGRectMake(tabW*2, 0, tabW, 44) title:@"⚙️ 默认值" tag:OverlayTabDefaults];
    [tabBar addSubview:self.tabSearchBtn];
    [tabBar addSubview:self.tabHooksBtn];
    [tabBar addSubview:self.tabDefaultsBtn];

    // 构建各面板（默认显示搜索）
    [self buildSearchPanel];
    [self buildHooksPanel];
    [self buildDefaultsPanel];
    [self switchToTab:OverlayTabSearch];
}

- (UIButton *)tabButtonWithFrame:(CGRect)frame title:(NSString *)title tag:(OverlayTab)tag {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = frame;
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    btn.tag = tag;
    [btn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)tabTapped:(UIButton *)sender {
    [self switchToTab:(OverlayTab)sender.tag];
}

- (void)switchToTab:(OverlayTab)tab {
    self.currentTab = tab;

    // 隐藏所有子面板
    for (UIView *v in self.contentArea.subviews) {
        v.hidden = YES;
    }

    // 重置 Tab 颜色
    NSArray *btns = @[self.tabSearchBtn, self.tabHooksBtn, self.tabDefaultsBtn];
    for (UIButton *b in btns) {
        [b setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        b.backgroundColor = [UIColor clearColor];
    }

    UIView *targetView = nil;
    UIColor *activeColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1];

    if (tab == OverlayTabSearch) {
        targetView = [self.contentArea viewWithTag:1001];
        self.tabSearchBtn.backgroundColor = activeColor;
        [self.tabSearchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else if (tab == OverlayTabHooks) {
        targetView = [self.contentArea viewWithTag:1002];
        self.tabHooksBtn.backgroundColor = activeColor;
        [self.tabHooksBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self refreshHooksList];
    } else if (tab == OverlayTabDefaults) {
        targetView = [self.contentArea viewWithTag:1003];
        self.tabDefaultsBtn.backgroundColor = activeColor;
        [self.tabDefaultsBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self refreshDefaults];
    }

    targetView.hidden = NO;
}

#pragma mark - 搜索面板

- (void)buildSearchPanel {
    CGFloat w = self.contentArea.frame.size.width;
    CGFloat h = self.contentArea.frame.size.height;
    UIView *view = [[UIView alloc] initWithFrame:self.contentArea.bounds];
    view.tag = 1001;

    // 搜索框
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(12, 8, w - 90, 34)];
    tf.placeholder = @"关键词（vip, token...）";
    tf.textColor = [UIColor whiteColor];
    tf.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    tf.layer.cornerRadius = 8;
    tf.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 0)];
    tf.leftViewMode = UITextFieldViewModeAlways;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.autocorrectionType = UITextAutocorrectionTypeNo;
    tf.returnKeyType = UIReturnKeySearch;
    tf.font = [UIFont systemFontOfSize:14];
    tf.delegate = self;
    [view addSubview:tf];
    self.searchField = tf;

    // 搜索按钮
    UIButton *searchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    searchBtn.frame = CGRectMake(w - 74, 8, 62, 34);
    [searchBtn setTitle:@"搜索" forState:UIControlStateNormal];
    [searchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    searchBtn.backgroundColor = [UIColor systemBlueColor];
    searchBtn.layer.cornerRadius = 8;
    searchBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [searchBtn addTarget:self action:@selector(searchTapped) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:searchBtn];
    self.searchButton = searchBtn;

    // 操作按钮行
    UIButton *hookBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    hookBtn.frame = CGRectMake(12, 46, 70, 26);
    [hookBtn setTitle:@"⚡ Hook" forState:UIControlStateNormal];
    [hookBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    hookBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.3 alpha:1];
    hookBtn.layer.cornerRadius = 6;
    hookBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [hookBtn addTarget:self action:@selector(hookFromSearchTapped) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:hookBtn];

    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(88, 46, 70, 26);
    [copyBtn setTitle:@"📋 复制" forState:UIControlStateNormal];
    [copyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1];
    copyBtn.layer.cornerRadius = 6;
    copyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [copyBtn addTarget:self action:@selector(copySearchResultTapped) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:copyBtn];

    // spinner
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.center = CGPointMake(w/2, h/2);
    spinner.hidesWhenStopped = YES;
    [view addSubview:spinner];
    self.spinner = spinner;

    // 结果
    UITextView *tv = [[UITextView alloc] initWithFrame:CGRectMake(6, 76, w-12, h-82)];
    tv.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    tv.textColor = [UIColor colorWithRed:0.4 green:0.9 blue:0.4 alpha:1];
    tv.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    tv.editable = NO;
    tv.layer.cornerRadius = 8;
    tv.contentInset = UIEdgeInsetsMake(8, 8, 8, 8);
    tv.text = @"输入关键词，点击搜索。\n支持: vip / token / user / pay ...";
    [view addSubview:tv];
    self.resultView = tv;

    [self.contentArea addSubview:view];
}

- (void)searchTapped {
    [self.searchField resignFirstResponder];
    NSString *keyword = self.searchField.text;
    if (keyword.length == 0) {
        self.resultView.text = @"⚠️ 请输入关键词";
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

            [self showToast:@"✅ 已复制到剪贴板"];
        });
    });
}

#pragma mark - 搜索面板操作

- (void)hookFromSearchTapped {
    NSString *keyword = self.searchField.text;
    if (keyword.length == 0) {
        [self showToast:@"⚠️ 先输入关键词搜索"];
        return;
    }
    // 用关键词预填 Hook 对话框
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚡ Hook 方法"
                                                                   message:@"输入要 Hook 的类名和方法名"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"类名";
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"方法名（含关键词）";
        tf.text = keyword;
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hook → YES" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *cls = alert.textFields[0].text;
        NSString *sel = alert.textFields[1].text;
        if (cls.length && sel.length) {
            BOOL ok = [MethodHacker hookMethodWithClass:cls methodName:sel isClassMethod:NO returnType:@"BOOL" value:@YES];
            [self showToast:ok ? @"✅ Hook 成功" : @"❌ 失败，检查类名/方法名"];
            [self refreshHooksList];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hook → NO" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        NSString *cls = alert.textFields[0].text;
        NSString *sel = alert.textFields[1].text;
        if (cls.length && sel.length) {
            BOOL ok = [MethodHacker hookMethodWithClass:cls methodName:sel isClassMethod:NO returnType:@"BOOL" value:@NO];
            [self showToast:ok ? @"✅ Hook 成功" : @"❌ 失败"];
            [self refreshHooksList];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    UIViewController *vc = [self viewControllerForPresent];
    if (vc) {
        [vc presentViewController:alert animated:YES completion:nil];
    } else {
        [self showToast:@"❌ 无法显示对话框"];
    }
}

- (void)copySearchResultTapped {
    if (self.resultView.text.length > 0) {
        [UIPasteboard generalPasteboard].string = self.resultView.text;
        [self showToast:@"✅ 已复制"];
    }
}

#pragma mark - Hooks 面板

- (void)buildHooksPanel {
    CGFloat w = self.contentArea.frame.size.width;
    CGFloat h = self.contentArea.frame.size.height;
    UIView *view = [[UIView alloc] initWithFrame:self.contentArea.bounds];
    view.tag = 1002;

    // 添加 Hook 按钮
    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    addBtn.frame = CGRectMake(12, 4, w - 24, 32);
    [addBtn setTitle:@"➕ 自定义 Hook" forState:UIControlStateNormal];
    [addBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    addBtn.backgroundColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.2 alpha:1];
    addBtn.layer.cornerRadius = 8;
    addBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [addBtn addTarget:self action:@selector(addHookTapped) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:addBtn];
    self.addHookButton = addBtn;

    // 快速 Hook 模板
    CGFloat btnY = 40;
    CGFloat btnW = (w - 36) / 3;
    NSArray *templates = @[
        @[@"🦸 VIP解锁", @"VIPManager", @"isVIPMember"],
        @[@"🦸 VIP解锁", @"UserInfo", @"isVIP"],
        @[@"🦸 VIP解锁", @"SettingsManager", @"isPremium"],
        @[@"🚫 去广告", @"AdManager", @"shouldShowAd"],
        @[@"🚫 去广告", @"ADManager", @"isAd"],
        @[@"🚫 去广告", @"BannerView", @"canDisplayAd"],
        @[@"🔓 全解锁", @"PaywallManager", @"isLocked"],
        @[@"🔓 全解锁", @"FeatureManager", @"hasAccess"],
    ];

    for (int i = 0; i < (int)templates.count; i++) {
        NSArray *t = templates[i];
        int row = i / 3;
        int col = i % 3;
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(12 + col * (btnW + 6), btnY + row * 30, btnW, 26);
        [btn setTitle:t[0] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.backgroundColor = [UIColor colorWithRed:0.25 green:0.35 blue:0.55 alpha:1];
        btn.layer.cornerRadius = 6;
        btn.titleLabel.font = [UIFont systemFontOfSize:10];
        // 关联参数
        objc_setAssociatedObject(btn, "_hook_cls", t[1], OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(btn, "_hook_sel", t[2], OBJC_ASSOCIATION_RETAIN);
        [btn addTarget:self action:@selector(quickHookTapped:) forControlEvents:UIControlEventTouchUpInside];
        [view addSubview:btn];
    }

    // 提示
    CGFloat tipY = btnY + ((templates.count + 2) / 3) * 30 + 4;
    UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(12, tipY, w-24, 18)];
    tip.text = @"活跃的 Hook（左滑取消）";
    tip.textColor = [UIColor lightGrayColor];
    tip.font = [UIFont systemFontOfSize:11];
    [view addSubview:tip];

    // 列表
    CGFloat tableY = tipY + 20;
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, tableY, w, h-tableY) style:UITableViewStylePlain];
    table.backgroundColor = [UIColor clearColor];
    table.dataSource = self;
    table.delegate = self;
    table.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    table.separatorColor = [UIColor colorWithWhite:0.3 alpha:0.5];
    [view addSubview:table];
    self.hooksTable = table;

    [self.contentArea addSubview:view];
}

- (void)quickHookTapped:(UIButton *)sender {
    NSString *cls = objc_getAssociatedObject(sender, "_hook_cls");
    NSString *sel = objc_getAssociatedObject(sender, "_hook_sel");
    if (!cls || !sel) return;

    // 判断应该返回 YES 还是 NO
    BOOL returnYES = YES;
    NSArray *noKeywords = @[@"Ad", @"ad", @"Locked", @"locked", @"Banner", @"banner"];
    for (NSString *kw in noKeywords) {
        if ([sel containsString:kw]) { returnYES = NO; break; }
    }

    BOOL ok = [MethodHacker hookMethodWithClass:cls methodName:sel isClassMethod:NO returnType:@"BOOL" value:@(returnYES)];
    if (ok) {
        [self showToast:[NSString stringWithFormat:@"✅ %@.%@ → %@", cls, sel, returnYES ? @"YES" : @"NO"]];
        [self refreshHooksList];
    } else {
        [self showToast:[NSString stringWithFormat:@"❌ %@.%@ 未找到", cls, sel]];
    }
}

- (void)refreshHooksList {
    self.hooksList = [MethodHacker activeHooks];
    [self.hooksTable reloadData];
}

- (void)addHookTapped {
    // 弹出输入框让用户输入 Hook 参数
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加 Hook"
                                                                   message:@"输入类名与方法名\n如: VIPManager isVIPMember"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"类名（如 VIPManager）";
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"方法名（如 isVIPMember）";
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];

    // 返回类型选择器
    __block NSString *selectedType = @"BOOL";
    NSArray *types = @[@"BOOL", @"id", @"NSInteger", @"double", @"void"];
    __block int typeIndex = 0;
    NSString *typeMsg = [NSString stringWithFormat:@"返回类型: %@ (点击切换)", types[typeIndex]];

    UIAlertAction *toggleType = [UIAlertAction actionWithTitle:typeMsg style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        typeIndex = (typeIndex + 1) % types.count;
        selectedType = types[typeIndex];
        // 重新弹窗（简化处理，直接递归）
        [self addHookTapped];
    }];

    UIAlertAction *confirm = [UIAlertAction actionWithTitle:@"确定 Hook" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *cls = [alert.textFields[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *sel = [alert.textFields[1].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        if (cls.length == 0 || sel.length == 0) {
            [self showToast:@"⚠️ 类名和方法名不能为空"];
            return;
        }

        // 确定返回值
        id retValue = @YES;
        if ([selectedType isEqualToString:@"BOOL"]) retValue = @YES;
        else if ([selectedType isEqualToString:@"id"]) retValue = @"(nil)";
        else if ([selectedType isEqualToString:@"NSInteger"]) retValue = @0;
        else if ([selectedType isEqualToString:@"double"]) retValue = @0.0;
        else if ([selectedType isEqualToString:@"void"]) retValue = nil;

        BOOL ok = [MethodHacker hookMethodWithClass:cls methodName:sel isClassMethod:NO returnType:selectedType value:retValue];
        if (ok) {
            [self showToast:[NSString stringWithFormat:@"✅ Hook %@.%@", cls, sel]];
            [self refreshHooksList];
        } else {
            [self showToast:[NSString stringWithFormat:@"❌ Hook 失败: %@.%@", cls, sel]];
        }
    }];

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];

    [alert addAction:toggleType];
    [alert addAction:confirm];
    [alert addAction:cancel];

    // 获取当前 VC 来 present
    UIViewController *vc = [self viewControllerForPresent];
    [vc presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Defaults 面板

- (void)buildDefaultsPanel {
    CGFloat w = self.contentArea.frame.size.width;
    CGFloat h = self.contentArea.frame.size.height;
    UIView *view = [[UIView alloc] initWithFrame:self.contentArea.bounds];
    view.tag = 1003;

    // 搜索框
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(12, 8, w - 24, 34)];
    tf.placeholder = @"搜索键名（留空显示全部）";
    tf.textColor = [UIColor whiteColor];
    tf.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    tf.layer.cornerRadius = 8;
    tf.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 0)];
    tf.leftViewMode = UITextFieldViewModeAlways;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.autocorrectionType = UITextAutocorrectionTypeNo;
    tf.returnKeyType = UIReturnKeySearch;
    tf.font = [UIFont systemFontOfSize:14];
    tf.delegate = self;
    tf.tag = 2001;
    [tf addTarget:self action:@selector(defaultsSearchChanged) forControlEvents:UIControlEventEditingChanged];
    [view addSubview:tf];
    self.defaultsSearchField = tf;

    // 复制按钮
    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(w - 60, 44, 48, 28);
    [copyBtn setTitle:@"📋" forState:UIControlStateNormal];
    [copyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyBtn.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1];
    copyBtn.layer.cornerRadius = 6;
    copyBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [copyBtn addTarget:self action:@selector(copyDefaultsTapped) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:copyBtn];

    // 刷新按钮
    UIButton *refreshBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    refreshBtn.frame = CGRectMake(12, 44, 48, 28);
    [refreshBtn setTitle:@"🔄" forState:UIControlStateNormal];
    [refreshBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    refreshBtn.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1];
    refreshBtn.layer.cornerRadius = 6;
    refreshBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [refreshBtn addTarget:self action:@selector(refreshDefaults) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:refreshBtn];

    // 列表
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 76, w, h-76) style:UITableViewStylePlain];
    table.backgroundColor = [UIColor clearColor];
    table.dataSource = self;
    table.delegate = self;
    table.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    table.separatorColor = [UIColor colorWithWhite:0.3 alpha:0.5];
    table.tag = 3001;
    [view addSubview:table];
    self.defaultsTable = table;

    [self.contentArea addSubview:view];
}

- (void)refreshDefaults {
    NSString *keyword = self.defaultsSearchField.text;
    if (keyword.length > 0) {
        self.defaultsData = [UserDefaultsEditor searchDefaultsWithKeyword:keyword];
    } else {
        self.defaultsData = [UserDefaultsEditor allDefaults];
    }
    self.defaultsKeys = [[self.defaultsData allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    [self.defaultsTable reloadData];
}

- (void)defaultsSearchChanged {
    [self refreshDefaults];
}

- (void)copyDefaultsTapped {
    NSString *report = [UserDefaultsEditor formatReport:self.defaultsData];
    [UIPasteboard generalPasteboard].string = report;
    [self showToast:@"✅ 已复制到剪贴板"];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.hooksTable) {
        return MAX(self.hooksList.count, 1);
    }
    return MAX(self.defaultsKeys.count, 1);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cid = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
        cell.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        cell.textLabel.font = [UIFont systemFontOfSize:13];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    if (tableView == self.hooksTable) {
        if (self.hooksList.count == 0) {
            cell.textLabel.text = @"暂无活跃 Hook";
            cell.detailTextLabel.text = @"点击上方按钮添加";
        } else {
            ActiveHook *h = self.hooksList[indexPath.row];
            cell.textLabel.text = [NSString stringWithFormat:@"%@.%@", h.className, h.methodName];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"→ %@ (%@)", h.returnValue ?: @"void", h.returnType];
        }
    } else if (tableView == self.defaultsTable) {
        if (self.defaultsKeys.count == 0) {
            cell.textLabel.text = @"无数据";
            cell.detailTextLabel.text = @"没有找到 UserDefaults 记录";
        } else {
            NSString *key = self.defaultsKeys[indexPath.row];
            id val = self.defaultsData[key];
            cell.textLabel.text = key;
            if ([val isKindOfClass:[NSData class]]) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"<Data: %lu bytes>", (unsigned long)[(NSData *)val length]];
            } else {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", val];
            }
        }

        // 左侧指示条
        if (self.defaultsKeys.count > 0) {
            UIView *indicator = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 3, 44)];
            indicator.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.3 alpha:1];
            [cell.contentView addSubview:indicator];
        }
    }

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.hooksTable && self.hooksList.count > 0) return YES;
    if (tableView == self.defaultsTable && self.defaultsKeys.count > 0) return YES;
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.hooksTable) {
        ActiveHook *h = self.hooksList[indexPath.row];
        [MethodHacker unhook:h];
        [self refreshHooksList];
    } else if (tableView == self.defaultsTable) {
        NSString *key = self.defaultsKeys[indexPath.row];
        [UserDefaultsEditor removeKey:key];
        [self refreshDefaults];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.hooksTable) return @"取消Hook";
    return @"删除";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.defaultsTable && self.defaultsKeys.count > 0) {
        NSString *key = self.defaultsKeys[indexPath.row];
        id val = self.defaultsData[key];
        [self showEditDefaultDialog:key currentValue:val];
    }
}

#pragma mark - 编辑 Defaults 值

- (void)showEditDefaultDialog:(NSString *)key currentValue:(id)value {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"编辑: %@", key]
                                                                   message:@"输入新值（NSString）"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = [NSString stringWithFormat:@"%@", value ?: @""];
        tf.placeholder = @"新值";
    }];

    UIAlertAction *save = [UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *newVal = alert.textFields[0].text;
        if (newVal) {
            [UserDefaultsEditor setValue:newVal forKey:key];
            [self refreshDefaults];
            [self showToast:[NSString stringWithFormat:@"✅ %@ = %@", key, newVal]];
        }
    }];

    UIAlertAction *delete_ = [UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [UserDefaultsEditor removeKey:key];
        [self refreshDefaults];
        [self showToast:[NSString stringWithFormat:@"🗑️ 已删除 %@", key]];
    }];

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:save];
    [alert addAction:delete_];
    [alert addAction:cancel];

    UIViewController *vc = [self viewControllerForPresent];
    [vc presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 辅助

- (void)showToast:(NSString *)msg {
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 220, 34)];
    toast.center = CGPointMake(self.panelView.frame.size.width / 2, self.panelView.frame.size.height / 2 - 20);
    toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];
    toast.textColor = [UIColor whiteColor];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.text = msg;
    toast.layer.cornerRadius = 8;
    toast.clipsToBounds = YES;
    toast.font = [UIFont systemFontOfSize:13];
    [self.panelView addSubview:toast];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [toast removeFromSuperview];
    });
}

- (UIViewController *)viewControllerForPresent {
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)s;
                for (UIWindow *w in ws.windows) {
                    UIViewController *root = w.rootViewController;
                    if (root) {
                        while (root.presentedViewController) root = root.presentedViewController;
                        return root;
                    }
                }
            }
        }
    }
    // 退回到 keyWindow
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    return root;
}

- (void)closeTapped {
    [SearchOverlayWindow dismiss];
}

- (void)dismissTapped {
    [self.searchField resignFirstResponder];
    [self.defaultsSearchField resignFirstResponder];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.searchField) {
        [self searchTapped];
    } else if (textField.tag == 2001) {
        [self refreshDefaults];
    }
    [textField resignFirstResponder];
    return YES;
}

@end
