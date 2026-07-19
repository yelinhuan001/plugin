#import "ToolboxViewController.h"
#import "ClassDumpSearcher.h"
#import "MethodHacker.h"
#import "UserDefaultsEditor.h"
#import "ProbeEngine.h"
#import <objc/runtime.h>

// ============================================================
#pragma mark - FloatingButton
// ============================================================
@implementation FloatingButton {
    UIPanGestureRecognizer *_pan;
    UITapGestureRecognizer *_tap;
}

static FloatingButton *_sharedBtn = nil;

+ (instancetype)sharedButton {
    if (!_sharedBtn) {
        _sharedBtn = [[self alloc] initWithFrame:CGRectMake(15, 120, 46, 46)];
    }
    return _sharedBtn;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:0.9];
        self.layer.cornerRadius = 23;
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 3);
        self.layer.shadowOpacity = 0.35;
        self.layer.shadowRadius = 5;
        self.userInteractionEnabled = YES;

        UILabel *icon = [[UILabel alloc] initWithFrame:self.bounds];
        icon.text = @"🔧";
        icon.textAlignment = NSTextAlignmentCenter;
        icon.font = [UIFont systemFontOfSize:22];
        icon.userInteractionEnabled = NO;
        [self addSubview:icon];

        _tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap)];
        [self addGestureRecognizer:_tap];

        _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
        [_pan requireGestureRecognizerToFail:_tap];
        [self addGestureRecognizer:_pan];
    }
    return self;
}

- (void)didTap {
    [ToolboxMenuController show];
}

- (void)didPan:(UIPanGestureRecognizer *)g {
    UIView *superview = self.superview;
    if (!superview) return;
    CGPoint t = [g translationInView:superview];
    CGPoint c = CGPointMake(self.center.x + t.x, self.center.y + t.y);
    CGFloat hw = self.frame.size.width/2, hh = self.frame.size.height/2;
    c.x = MAX(hw, MIN(superview.bounds.size.width - hw, c.x));
    c.y = MAX(hh + 60, MIN(superview.bounds.size.height - hh, c.y));
    self.center = c;
    [g setTranslation:CGPointZero inView:superview];
    if (g.state == UIGestureRecognizerStateEnded) {
        CGFloat targetX = (c.x < superview.bounds.size.width/2) ? hw + 6 : superview.bounds.size.width - hw - 6;
        [UIView animateWithDuration:0.25 animations:^{
            self.center = CGPointMake(targetX, self.center.y);
        }];
    }
}

@end

#pragma mark - 入口
__attribute__((constructor)) static void toolbox_init() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        FloatingButton *btn = [FloatingButton sharedButton];
        UIWindow *target = nil;
        if (@available(iOS 13, *)) {
            for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
                if ([s isKindOfClass:UIWindowScene.class]) {
                    UIWindowScene *ws = (UIWindowScene *)s;
                    if (ws.activationState == UISceneActivationStateForegroundActive) {
                        target = ws.windows.firstObject;
                        break;
                    }
                }
            }
        }
        if (!target) target = UIApplication.sharedApplication.keyWindow;
        if (!target) target = UIApplication.sharedApplication.windows.firstObject;
        if (target) {
            [target addSubview:btn];
            NSLog(@"[Toolbox] 注入成功！点击🔧浮动按钮打开工具箱");
        }
    });
}

// ============================================================
#pragma mark - ToolboxMenuController (主菜单)
// ============================================================
@implementation ToolboxMenuController

static ToolboxMenuController *_menu = nil;
static UINavigationController *_nav = nil;

+ (void)show {
    if (_nav && _nav.presentingViewController) {
        [_nav dismissViewControllerAnimated:YES completion:nil];
        _nav = nil; _menu = nil;
        return;
    }
    _menu = [[self alloc] initWithStyle:UITableViewStyleInsetGrouped];
    _menu.title = @"🔧 工具箱";
    _nav = [[UINavigationController alloc] initWithRootViewController:_menu];
    _nav.modalPresentationStyle = UIModalPresentationPageSheet;
    
    if (@available(iOS 15, *)) {
        UISheetPresentationController *sheet = _nav.sheetPresentationController;
        sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent,
                          UISheetPresentationControllerDetent.largeDetent];
        sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
        sheet.prefersGrabberVisible = YES;
        sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
    }

    UIViewController *root = [self _topVC];
    [root presentViewController:_nav animated:YES completion:nil];
}

+ (UIViewController *)_topVC {
    if (@available(iOS 13, *)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:UIWindowScene.class]) {
                for (UIWindow *w in [(UIWindowScene *)s windows]) {
                    UIViewController *r = w.rootViewController;
                    if (!r) continue;
                    while (r.presentedViewController) r = r.presentedViewController;
                    return r;
                }
            }
        }
    }
    UIViewController *r = UIApplication.sharedApplication.keyWindow.rootViewController;
    while (r.presentedViewController) r = r.presentedViewController;
    return r;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.3 alpha:0.4];
    self.tableView.rowHeight = 52;
    
    UIBarButtonItem *close = [[UIBarButtonItem alloc] initWithTitle:@"✕" style:UIBarButtonItemStyleDone
                                                             target:self action:@selector(dismissSelf)];
    close.tintColor = UIColor.lightGrayColor;
    self.navigationItem.rightBarButtonItem = close;
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
    _nav = nil; _menu = nil;
}

// MARK: - Table Data
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 4; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec {
    return @[@1, @2, @2, @1][sec].integerValue;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)sec {
    return @[@"🔍 类搜索", @"🪝 Hook", @"📡 探测", @"📋 其他"][sec];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"cell"];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
        c.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1];
        c.textLabel.textColor = UIColor.whiteColor;
        c.detailTextLabel.textColor = UIColor.lightGrayColor;
        c.textLabel.font = [UIFont systemFontOfSize:15];
        c.detailTextLabel.font = [UIFont systemFontOfSize:11];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    NSArray *rows = @[
        @[@{@"title":@"🔍 搜索类与方法", @"sub":@"按关键词搜索运行时类和方法"}],
        @[@{@"title":@"🪝 Hook 管理", @"sub":@"查看/添加/删除 Hook"},
          @{@"title":@"⚡ 快速 Hook", @"sub":@"一键 Hook VIP/去广告模板"}],
        @[@{@"title":@"📡 运行时探测", @"sub":@"自动扫描关键词方法并获取返回值"},
          @{@"title":@"🦸 VIP 专项分析", @"sub":@"专门扫描 VIP/会员相关方法"}],
        @[@{@"title":@"⚙️ UserDefaults", @"sub":@"浏览/编辑 NSUserDefaults"}],
    ];
    NSDictionary *d = rows[ip.section][ip.row];
    c.textLabel.text = d[@"title"];
    c.detailTextLabel.text = d[@"sub"];
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    UIViewController *vc = nil;
    
    if (ip.section == 0) {
        vc = [ClassSearchController new];
    } else if (ip.section == 1) {
        if (ip.row == 0) vc = [HookManageController new];
        else vc = [QuickHookController new];
    } else if (ip.section == 2) {
        if (ip.row == 0) vc = [ProbeController new];
        else vc = [VIPProbeController new];
    } else if (ip.section == 3) {
        vc = [DefaultsEditorController new];
    }
    if (vc) [self.navigationController pushViewController:vc animated:YES];
}

@end

// ============================================================
#pragma mark - ClassSearchController
// ============================================================
@implementation ClassSearchController {
    UITextField *_field;
    UITextView *_result;
    UIActivityIndicatorView *_spinner;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"🔍 类搜索";
    self.view.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    
    _field = [[UITextField alloc] initWithFrame:CGRectMake(12, 10, self.view.frame.size.width-24, 36)];
    _field.placeholder = @"关键词 (vip, token...)";
    _field.textColor = UIColor.whiteColor;
    _field.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    _field.layer.cornerRadius = 8;
    _field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,10,0)];
    _field.leftViewMode = UITextFieldViewModeAlways;
    _field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _field.autocorrectionType = UITextAutocorrectionTypeNo;
    _field.returnKeyType = UIReturnKeySearch;
    _field.font = [UIFont systemFontOfSize:14];
    _field.delegate = self;
    _field.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_field];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"搜索" forState:UIControlStateNormal];
    [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    btn.backgroundColor = UIColor.systemBlueColor;
    btn.layer.cornerRadius = 8;
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [btn addTarget:self action:@selector(search) forControlEvents:UIControlEventTouchUpInside];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:btn];
    
    _result = [UITextView new];
    _result.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    _result.textColor = [UIColor colorWithRed:0.4 green:0.9 blue:0.4 alpha:1];
    _result.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    _result.editable = NO;
    _result.layer.cornerRadius = 8;
    _result.translatesAutoresizingMaskIntoConstraints = NO;
    _result.text = @"输入关键词，点击搜索";
    [self.view addSubview:_result];
    
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.hidesWhenStopped = YES;
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_spinner];
    
    // Auto Layout
    [NSLayoutConstraint activateConstraints:@[
        [_field.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [_field.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_field.trailingAnchor constraintEqualToAnchor:btn.leadingAnchor constant:-8],
        [_field.heightAnchor constraintEqualToConstant:36],
        
        [btn.centerYAnchor constraintEqualToAnchor:_field.centerYAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [btn.widthAnchor constraintEqualToConstant:60],
        [btn.heightAnchor constraintEqualToConstant:36],
        
        [_result.topAnchor constraintEqualToAnchor:_field.bottomAnchor constant:10],
        [_result.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:6],
        [_result.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-6],
        [_result.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-10],
        
        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

- (void)search {
    [_field resignFirstResponder];
    NSString *kw = _field.text;
    if (kw.length == 0) { _result.text = @"请输入关键词"; return; }
    _result.text = @""; [_spinner startAnimating];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSString *r = [ClassDumpSearcher searchAndCopyWithKeyword:kw];
        dispatch_async(dispatch_get_main_queue(), ^{
            [_spinner stopAnimating];
            _result.text = r;
        });
    });
}

- (BOOL)textFieldShouldReturn:(UITextField *)t { [self search]; return YES; }
@end

// ============================================================
#pragma mark - QuickHookController
// ============================================================
@implementation QuickHookController {
    NSArray *_templates;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"⚡ 快速 Hook";
    self.view.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    
    _templates = @[
        @[@"🦸 VIP解锁", @"VIPManager", @"isVIPMember"],
        @[@"🦸 VIP解锁", @"UserInfo", @"isVIP"],
        @[@"🦸 VIP解锁", @"SettingsManager", @"isPremium"],
        @[@"🚫 去广告", @"AdManager", @"shouldShowAd"],
        @[@"🚫 去广告", @"ADManager", @"isAd"],
        @[@"🔓 功能解锁", @"PaywallManager", @"isLocked"],
        @[@"🔓 功能解锁", @"FeatureManager", @"hasAccess"],
        @[@"🔓 功能解锁", @"PurchaseManager", @"hasPurchased"],
    ];
    
    CGFloat y = 20, w = self.view.frame.size.width - 24;
    UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(12, y, w, 24)];
    tip.text = @"点击以下模板一键 Hook：";
    tip.textColor = UIColor.lightGrayColor;
    tip.font = [UIFont systemFontOfSize:13];
    [self.view addSubview:tip];
    y += 30;
    
    for (int i = 0; i < _templates.count; i++) {
        NSArray *t = _templates[i];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(12, y + (i/2)*50, (w-6)/2, 44);
        b.backgroundColor = [UIColor colorWithRed:0.22 green:0.32 blue:0.52 alpha:1];
        b.layer.cornerRadius = 10;
        [b setTitle:t[0] forState:UIControlStateNormal];
        [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        b.tag = i;
        [b addTarget:self action:@selector(hookTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:b];
    }
    
    UILabel *tip2 = [[UILabel alloc] initWithFrame:CGRectMake(12, y + (_templates.count/2)*50 + 10, w, 20)];
    tip2.text = @"💡 也可在「Hook管理」中自定义";
    tip2.textColor = UIColor.darkGrayColor;
    tip2.font = [UIFont systemFontOfSize:11];
    [self.view addSubview:tip2];
}

- (void)hookTapped:(UIButton *)s {
    NSArray *t = _templates[s.tag];
    NSString *cls = t[1], *sel = t[2];
    BOOL rYES = YES;
    if ([sel containsString:@"Ad"]||[sel containsString:@"ad"]||[sel containsString:@"Locked"]||[sel containsString:@"lock"]) rYES = NO;
    BOOL ok = [MethodHacker hookMethodWithClass:cls methodName:sel isClassMethod:NO returnType:@"BOOL" value:@(rYES)];
    NSString *msg = ok ? [NSString stringWithFormat:@"✅ %@.%@ → %@", cls, sel, rYES?@"YES":@"NO"]
                       : [NSString stringWithFormat:@"❌ %@.%@ 未找到", cls, sel];
    [self toast:msg];
}

- (void)toast:(NSString *)msg {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0,0,220,34)];
    l.center = CGPointMake(self.view.frame.size.width/2, 80);
    l.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];
    l.textColor = UIColor.whiteColor;
    l.textAlignment = NSTextAlignmentCenter;
    l.text = msg; l.layer.cornerRadius = 8;
    l.clipsToBounds = YES; l.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:l];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [l removeFromSuperview];
    });
}
@end

// ============================================================
#pragma mark - HookManageController
// ============================================================
@implementation HookManageController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"🪝 Hook 管理";
    self.tableView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.3 alpha:0.4];
    self.tableView.rowHeight = 50;
    
    UIBarButtonItem *add = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                        target:self action:@selector(addHook)];
    add.tintColor = UIColor.systemBlueColor;
    self.navigationItem.rightBarButtonItem = add;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec {
    NSArray *hooks = [MethodHacker activeHooks];
    return MAX(hooks.count, 1);
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"c"];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"c"];
        c.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1];
        c.textLabel.textColor = UIColor.whiteColor;
        c.detailTextLabel.textColor = UIColor.lightGrayColor;
        c.textLabel.font = [UIFont systemFontOfSize:14];
        c.detailTextLabel.font = [UIFont systemFontOfSize:11];
    }
    NSArray *hooks = [MethodHacker activeHooks];
    if (hooks.count == 0) {
        c.textLabel.text = @"暂无活跃 Hook";
        c.detailTextLabel.text = @"点击右上角 + 添加";
        c.accessoryType = UITableViewCellAccessoryNone;
    } else {
        ActiveHook *h = hooks[ip.row];
        c.textLabel.text = [NSString stringWithFormat:@"%@.%@", h.className, h.methodName];
        c.detailTextLabel.text = [NSString stringWithFormat:@"值: %@ | 调用%lu次", h.returnValue?:@"void", (unsigned long)h.callCount];
        c.accessoryType = UITableViewCellAccessoryNone;
    }
    return c;
}

- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip {
    return [MethodHacker activeHooks].count > 0;
}

- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)ed forRowAtIndexPath:(NSIndexPath *)ip {
    NSArray *hooks = [MethodHacker activeHooks];
    if (ip.row < hooks.count) {
        [MethodHacker unhook:hooks[ip.row]];
        [tv reloadData];
    }
}

- (void)addHook {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"添加 Hook" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder = @"类名 (如 VIPManager)"; }];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder = @"方法名 (如 isVIP)"; }];
    [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(id act){
        NSString *c = [a.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSString *s = [a.textFields[1].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (c.length && s.length) {
            [MethodHacker hookMethodWithClass:c methodName:s isClassMethod:NO returnType:@"BOOL" value:@YES];
            [self.tableView reloadData];
        }
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

@end

// ============================================================
#pragma mark - ProbeController
// ============================================================
@implementation ProbeController {
    UITextView *_resultView;
    UIButton *_probeBtn;
    UIProgressView *_progress;
    UILabel *_statusLabel;
    UIActivityIndicatorView *_spinner;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"📡 运行时探测";
    self.view.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    
    _probeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_probeBtn setTitle:@"▶️ 开始探测" forState:UIControlStateNormal];
    [_probeBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _probeBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.3 alpha:1];
    _probeBtn.layer.cornerRadius = 8;
    _probeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [_probeBtn addTarget:self action:@selector(startProbe) forControlEvents:UIControlEventTouchUpInside];
    _probeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_probeBtn];
    
    _progress = [UIProgressView new];
    _progress.progressTintColor = UIColor.systemGreenColor;
    _progress.hidden = YES;
    _progress.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_progress];
    
    _statusLabel = [UILabel new];
    _statusLabel.textColor = UIColor.lightGrayColor;
    _statusLabel.font = [UIFont systemFontOfSize:11];
    _statusLabel.hidden = YES;
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_statusLabel];
    
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.hidesWhenStopped = YES;
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_spinner];
    
    _resultView = [UITextView new];
    _resultView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    _resultView.textColor = [UIColor colorWithRed:0.4 green:0.9 blue:0.4 alpha:1];
    _resultView.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    _resultView.editable = NO;
    _resultView.layer.cornerRadius = 8;
    _resultView.translatesAutoresizingMaskIntoConstraints = NO;
    _resultView.text = @"点击「开始探测」自动扫描 300+ 类的关键词方法";
    [self.view addSubview:_resultView];
    
    [NSLayoutConstraint activateConstraints:@[
        [_probeBtn.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [_probeBtn.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_probeBtn.widthAnchor constraintEqualToConstant:110],
        [_probeBtn.heightAnchor constraintEqualToConstant:34],
        
        [_progress.topAnchor constraintEqualToAnchor:_probeBtn.bottomAnchor constant:8],
        [_progress.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_progress.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [_progress.heightAnchor constraintEqualToConstant:4],
        
        [_statusLabel.topAnchor constraintEqualToAnchor:_progress.bottomAnchor constant:2],
        [_statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        
        [_resultView.topAnchor constraintEqualToAnchor:_probeBtn.bottomAnchor constant:20],
        [_resultView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:6],
        [_resultView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-6],
        [_resultView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-10],
        
        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

- (void)startProbe {
    _probeBtn.enabled = NO; _progress.hidden = NO; _progress.progress = 0;
    _statusLabel.hidden = NO; _statusLabel.text = @"准备中...";
    _resultView.text = @""; [_spinner startAnimating];
    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSArray *r = [ProbeEngine runProbeWithMaxClasses:300 progress:^(float p, NSString *c) {
            dispatch_async(dispatch_get_main_queue(), ^{
                ws->_progress.progress = p;
                ws->_statusLabel.text = [NSString stringWithFormat:@"%.0f%% %@", p*100, c];
            });
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            [ws->_spinner stopAnimating]; ws->_probeBtn.enabled = YES;
            ws->_progress.hidden = YES; ws->_statusLabel.hidden = YES;
            ws->_resultView.text = [ProbeEngine formatReport:r];
            [UIPasteboard generalPasteboard].string = ws->_resultView.text;
        });
    });
}
@end

// ============================================================
#pragma mark - VIPProbeController
// ============================================================
@implementation VIPProbeController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"🦸 VIP 分析";
    self.view.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    
    UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(12, 20, self.view.frame.size.width-24, 40)];
    tip.text = @"正在自动扫描 VIP 相关方法...\n请稍候";
    tip.textColor = UIColor.lightGrayColor;
    tip.font = [UIFont systemFontOfSize:13];
    tip.numberOfLines = 2;
    tip.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:tip];
    
    UIActivityIndicatorView *sp = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    sp.translatesAutoresizingMaskIntoConstraints = NO;
    [sp startAnimating];
    [self.view addSubview:sp];
    
    UITextView *tv = [UITextView new];
    tv.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    tv.textColor = [UIColor colorWithRed:0.4 green:0.9 blue:0.4 alpha:1];
    tv.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    tv.editable = NO; tv.layer.cornerRadius = 8;
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:tv];
    
    [NSLayoutConstraint activateConstraints:@[
        [tip.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [tip.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [sp.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [sp.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [tv.topAnchor constraintEqualToAnchor:tip.bottomAnchor constant:10],
        [tv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:6],
        [tv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-6],
        [tv.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-10],
    ]];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSArray *r = [ProbeEngine runProbeWithMaxClasses:300 progress:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            [sp stopAnimating];
            tip.text = @"✅ VIP 分析完成";
            tv.text = [ProbeEngine formatVIPReport:r];
            [UIPasteboard generalPasteboard].string = tv.text;
        });
    });
}
@end

// ============================================================
#pragma mark - DefaultsEditorController
// ============================================================
@implementation DefaultsEditorController {
    UISearchController *_searchCtrl;
    NSArray *_keys;
    NSDictionary *_data;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"⚙️ UserDefaults";
    self.tableView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.3 alpha:0.4];
    
    _searchCtrl = [[UISearchController alloc] initWithSearchResultsController:nil];
    _searchCtrl.searchResultsUpdater = (id)self;
    _searchCtrl.obscuresBackgroundDuringPresentation = NO;
    _searchCtrl.searchBar.placeholder = @"搜索键名";
    _searchCtrl.searchBar.barStyle = UIBarStyleBlack;
    self.navigationItem.searchController = _searchCtrl;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    
    _data = [UserDefaultsEditor allDefaults];
    _keys = [_data.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec {
    return MAX(_keys.count, 1);
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"c"];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"c"];
        c.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1];
        c.textLabel.textColor = UIColor.whiteColor;
        c.detailTextLabel.textColor = UIColor.lightGrayColor;
        c.textLabel.font = [UIFont systemFontOfSize:12];
        c.detailTextLabel.font = [UIFont systemFontOfSize:10];
    }
    if (_keys.count == 0) {
        c.textLabel.text = @"无数据";
        c.detailTextLabel.text = nil;
    } else {
        NSString *k = _keys[ip.row];
        id v = _data[k];
        c.textLabel.text = k;
        c.detailTextLabel.text = [v isKindOfClass:NSData.class] ?
            [NSString stringWithFormat:@"<Data: %lu bytes>", (unsigned long)[(NSData*)v length]] :
            [NSString stringWithFormat:@"%@", v];
    }
    return c;
}

- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip {
    return _keys.count > 0;
}

- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)ed forRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.row < _keys.count) {
        [UserDefaultsEditor removeKey:_keys[ip.row]];
        _data = [UserDefaultsEditor allDefaults];
        _keys = [_data.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        [tv reloadData];
    }
}

- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    NSString *kw = sc.searchBar.text;
    _data = kw.length ? [UserDefaultsEditor searchDefaultsWithKeyword:kw] : [UserDefaultsEditor allDefaults];
    _keys = [_data.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    [self.tableView reloadData];
}
@end

// ============================================================
#pragma mark - ToolboxLauncher
// ============================================================
@implementation ToolboxLauncher
+ (void)launch { /* 由 FloatingButton +load 自动触发 */ }
@end
