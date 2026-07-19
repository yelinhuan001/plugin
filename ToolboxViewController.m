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
    UIView *sv = self.superview;
    if (!sv) return;
    CGPoint t = [g translationInView:sv];
    CGPoint c = CGPointMake(self.center.x + t.x, self.center.y + t.y);
    CGFloat hw = self.frame.size.width/2, hh = self.frame.size.height/2;
    c.x = MAX(hw, MIN(sv.bounds.size.width - hw, c.x));
    c.y = MAX(hh + 60, MIN(sv.bounds.size.height - hh, c.y));
    self.center = c;
    [g setTranslation:CGPointZero inView:sv];
    if (g.state == UIGestureRecognizerStateEnded) {
        CGFloat tx = (c.x < sv.bounds.size.width/2) ? hw + 6 : sv.bounds.size.width - hw - 6;
        [UIView animateWithDuration:0.25 animations:^{ self.center = CGPointMake(tx, self.center.y); }];
    }
}

@end

// ============================================================
#pragma mark - 入口
// ============================================================
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
#pragma mark - ToolboxMenuController
// ============================================================
@interface ToolboxMenuController () {
    NSArray *_sections;
}
@end

@implementation ToolboxMenuController

static UINavigationController *_nav = nil;

+ (void)show {
    if (_nav && _nav.presentingViewController) {
        [_nav dismissViewControllerAnimated:YES completion:nil];
        _nav = nil;
        return;
    }
    ToolboxMenuController *menu = [ToolboxMenuController new];
    menu.title = @"🔧 工具箱";
    _nav = [[UINavigationController alloc] initWithRootViewController:menu];
    _nav.modalPresentationStyle = UIModalPresentationPageSheet;

    if (@available(iOS 15, *)) {
        UISheetPresentationController *sheet = _nav.sheetPresentationController;
        sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent,
                          UISheetPresentationControllerDetent.largeDetent];
        sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
        sheet.prefersGrabberVisible = YES;
        sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
    }

    UIViewController *top = nil;
    if (@available(iOS 13, *)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:UIWindowScene.class]) {
                for (UIWindow *w in [(UIWindowScene *)s windows]) {
                    top = w.rootViewController;
                    if (top) break;
                }
            }
        }
    }
    if (!top) top = UIApplication.sharedApplication.keyWindow.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if (top) [top presentViewController:_nav animated:YES completion:nil];
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

    _sections = @[
        @{@"title": @"🔍 类搜索", @"items": @[@{@"title": @"🔍 搜索类与方法", @"sub": @"按关键词搜索运行时类", @"vc": [ClassSearchController class]}]},
        @{@"title": @"🪝 Hook", @"items": @[@{@"title": @"🪝 Hook 管理", @"sub": @"查看/添加/删除 Hook", @"vc": [HookManageController class]},
                                             @{@"title": @"⚡ 快速 Hook", @"sub": @"一键Hook VIP/去广告", @"vc": [QuickHookController class]}]},
        @{@"title": @"📡 探测", @"items": @[@{@"title": @"📡 运行时探测", @"sub": @"自动扫描关键词方法", @"vc": [ProbeController class]},
                                             @{@"title": @"🦸 VIP 分析", @"sub": @"扫描VIP/会员相关方法", @"vc": [VIPProbeController class]}]},
        @{@"title": @"⚙️ 其他", @"items": @[@{@"title": @"⚙️ UserDefaults", @"sub": @"浏览/编辑NSUserDefaults", @"vc": [DefaultsEditorController class]}]},
    ];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
    _nav = nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return _sections.count; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return _sections[s][@"title"]; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [_sections[s][@"items"] count]; }

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
    NSDictionary *item = _sections[ip.section][@"items"][ip.row];
    c.textLabel.text = item[@"title"];
    c.detailTextLabel.text = item[@"sub"];
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *item = _sections[ip.section][@"items"][ip.row];
    Class vcClass = item[@"vc"];
    if (vcClass) [self.navigationController pushViewController:[vcClass new] animated:YES];
}

@end

// ============================================================
#pragma mark - ClassSearchController
// ============================================================
@interface ClassSearchController ()
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, strong) UITextView *resultView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation ClassSearchController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"🔍 类搜索";
    self.view.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];

    self.field = [UITextField new];
    self.field.placeholder = @"关键词 (vip, token...)";
    self.field.textColor = UIColor.whiteColor;
    self.field.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    self.field.layer.cornerRadius = 8;
    self.field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,10,0)];
    self.field.leftViewMode = UITextFieldViewModeAlways;
    self.field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.field.autocorrectionType = UITextAutocorrectionTypeNo;
    self.field.returnKeyType = UIReturnKeySearch;
    self.field.font = [UIFont systemFontOfSize:14];
    self.field.delegate = self;
    self.field.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.field];

    UIButton *searchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [searchBtn setTitle:@"搜索" forState:UIControlStateNormal];
    [searchBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    searchBtn.backgroundColor = UIColor.systemBlueColor;
    searchBtn.layer.cornerRadius = 8;
    searchBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [searchBtn addTarget:self action:@selector(searchAction) forControlEvents:UIControlEventTouchUpInside];
    searchBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:searchBtn];

    self.resultView = [UITextView new];
    self.resultView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    self.resultView.textColor = [UIColor colorWithRed:0.4 green:0.9 blue:0.4 alpha:1];
    self.resultView.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.resultView.editable = NO;
    self.resultView.layer.cornerRadius = 8;
    self.resultView.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultView.text = @"输入关键词，点击搜索";
    [self.view addSubview:self.resultView];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.spinner];

    [NSLayoutConstraint activateConstraints:@[
        [self.field.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [self.field.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.field.trailingAnchor constraintEqualToAnchor:searchBtn.leadingAnchor constant:-8],
        [self.field.heightAnchor constraintEqualToConstant:36],
        [searchBtn.centerYAnchor constraintEqualToAnchor:self.field.centerYAnchor],
        [searchBtn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [searchBtn.widthAnchor constraintEqualToConstant:60],
        [searchBtn.heightAnchor constraintEqualToConstant:36],
        [self.resultView.topAnchor constraintEqualToAnchor:self.field.bottomAnchor constant:10],
        [self.resultView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:6],
        [self.resultView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-6],
        [self.resultView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-10],
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

- (void)searchAction {
    [self.field resignFirstResponder];
    NSString *kw = self.field.text;
    if (kw.length == 0) { self.resultView.text = @"请输入关键词"; return; }
    self.resultView.text = @"";
    [self.spinner startAnimating];
    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSString *r = [ClassDumpSearcher searchAndCopyWithKeyword:kw];
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) strongSelf = ws;
            [strongSelf.spinner stopAnimating];
            strongSelf.resultView.text = r;
        });
    });
}

- (BOOL)textFieldShouldReturn:(UITextField *)t { [self searchAction]; return YES; }
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

    for (int i = 0; i < (int)_templates.count; i++) {
        NSArray *t = _templates[i];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(12 + (i%2)*((w-6)/2+6), y + (i/2)*50, (w-6)/2, 44);
        b.backgroundColor = [UIColor colorWithRed:0.22 green:0.32 blue:0.52 alpha:1];
        b.layer.cornerRadius = 10;
        [b setTitle:t[0] forState:UIControlStateNormal];
        [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        b.tag = i;
        [b addTarget:self action:@selector(hookTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:b];
    }
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [l removeFromSuperview]; });
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
    UIBarButtonItem *add = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addHook)];
    add.tintColor = UIColor.systemBlueColor;
    self.navigationItem.rightBarButtonItem = add;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec {
    return MAX([MethodHacker activeHooks].count, 1);
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
    } else {
        ActiveHook *h = hooks[ip.row];
        c.textLabel.text = [NSString stringWithFormat:@"%@.%@", h.className, h.methodName];
        c.detailTextLabel.text = [NSString stringWithFormat:@"值: %@ | %lu次", h.returnValue?:@"void", (unsigned long)h.callCount];
    }
    return c;
}

- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip {
    return [MethodHacker activeHooks].count > 0;
}

- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)ed forRowAtIndexPath:(NSIndexPath *)ip {
    NSArray *hooks = [MethodHacker activeHooks];
    if (ip.row < hooks.count) { [MethodHacker unhook:hooks[ip.row]]; [tv reloadData]; }
}

- (void)addHook {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"添加 Hook" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder = @"类名"; }];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder = @"方法名"; }];
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
@interface ProbeController ()
@property (nonatomic, strong) UITextView *resultView;
@property (nonatomic, strong) UIButton *probeBtn;
@property (nonatomic, strong) UIProgressView *progress;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation ProbeController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"📡 运行时探测";
    self.view.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];

    self.probeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.probeBtn setTitle:@"▶️ 开始探测" forState:UIControlStateNormal];
    [self.probeBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.probeBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.3 alpha:1];
    self.probeBtn.layer.cornerRadius = 8;
    self.probeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.probeBtn addTarget:self action:@selector(startProbe) forControlEvents:UIControlEventTouchUpInside];
    self.probeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.probeBtn];

    self.progress = [UIProgressView new];
    self.progress.progressTintColor = UIColor.systemGreenColor;
    self.progress.hidden = YES;
    self.progress.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.progress];

    self.statusLabel = [UILabel new];
    self.statusLabel.textColor = UIColor.lightGrayColor;
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.hidden = YES;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.spinner];

    self.resultView = [UITextView new];
    self.resultView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    self.resultView.textColor = [UIColor colorWithRed:0.4 green:0.9 blue:0.4 alpha:1];
    self.resultView.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    self.resultView.editable = NO;
    self.resultView.layer.cornerRadius = 8;
    self.resultView.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultView.text = @"点击「开始探测」自动扫描 300+ 类的关键词方法";
    [self.view addSubview:self.resultView];

    [NSLayoutConstraint activateConstraints:@[
        [self.probeBtn.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [self.probeBtn.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.probeBtn.widthAnchor constraintEqualToConstant:110],
        [self.probeBtn.heightAnchor constraintEqualToConstant:34],
        [self.progress.topAnchor constraintEqualToAnchor:self.probeBtn.bottomAnchor constant:8],
        [self.progress.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.progress.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.progress.bottomAnchor constant:2],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.resultView.topAnchor constraintEqualToAnchor:self.probeBtn.bottomAnchor constant:20],
        [self.resultView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:6],
        [self.resultView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-6],
        [self.resultView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-10],
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

- (void)startProbe {
    self.probeBtn.enabled = NO;
    self.progress.hidden = NO; self.progress.progress = 0;
    self.statusLabel.hidden = NO; self.statusLabel.text = @"准备中...";
    self.resultView.text = @"";
    [self.spinner startAnimating];
    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSArray *r = [ProbeEngine runProbeWithMaxClasses:300 progress:^(float p, NSString *c) {
            dispatch_async(dispatch_get_main_queue(), ^{
                typeof(self) s = ws;
                s.progress.progress = p;
                s.statusLabel.text = [NSString stringWithFormat:@"%.0f%% %@", p*100, c];
            });
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) s = ws;
            [s.spinner stopAnimating]; s.probeBtn.enabled = YES;
            s.progress.hidden = YES; s.statusLabel.hidden = YES;
            s.resultView.text = [ProbeEngine formatReport:r];
            [UIPasteboard generalPasteboard].string = s.resultView.text;
        });
    });
}

@end

// ============================================================
#pragma mark - VIPProbeController
// ============================================================
@implementation VIPProbeController {
    UITextView *_resultView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"🦸 VIP 分析";
    self.view.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];

    UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(12, 20, self.view.frame.size.width-24, 40)];
    tip.text = @"正在自动扫描 VIP 相关方法...";
    tip.textColor = UIColor.lightGrayColor;
    tip.font = [UIFont systemFontOfSize:13];
    tip.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:tip];

    UIActivityIndicatorView *sp = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    sp.translatesAutoresizingMaskIntoConstraints = NO;
    [sp startAnimating];
    [self.view addSubview:sp];

    _resultView = [UITextView new];
    _resultView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    _resultView.textColor = [UIColor colorWithRed:0.4 green:0.9 blue:0.4 alpha:1];
    _resultView.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    _resultView.editable = NO; _resultView.layer.cornerRadius = 8;
    _resultView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_resultView];

    [NSLayoutConstraint activateConstraints:@[
        [tip.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [tip.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [sp.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [sp.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_resultView.topAnchor constraintEqualToAnchor:tip.bottomAnchor constant:10],
        [_resultView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:6],
        [_resultView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-6],
        [_resultView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-10],
    ]];

    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSArray *r = [ProbeEngine runProbeWithMaxClasses:300 progress:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) s = ws;
            [sp stopAnimating];
            tip.text = @"✅ VIP 分析完成";
            s->_resultView.text = [ProbeEngine formatVIPReport:r];
            [UIPasteboard generalPasteboard].string = s->_resultView.text;
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
