#import "ToolboxViewController.h"
#import "ClassDumpSearcher.h"
#import "MethodHacker.h"
#import "UserDefaultsEditor.h"
#import "ProbeEngine.h"
#import <objc/runtime.h>

// ======== FloatingButton ========
@interface FloatingButton : UIView
+ (instancetype)sharedButton;
+ (void)show;
+ (void)hide;
@end

static FloatingButton *_sharedFloatingButton = nil;
static ToolboxViewController *_sharedToolbox = nil;

// ======== ToolboxViewController ========
@interface ToolboxViewController () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIScrollView *tabScrollView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *tabButtons;
@property (nonatomic, assign) NSInteger currentTab;
// 搜索
@property (nonatomic, strong) UITextField *searchField;
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

@implementation ToolboxViewController

+ (void)show {
    if (_sharedToolbox) {
        [_sharedToolbox dismissViewControllerAnimated:NO completion:nil];
        _sharedToolbox = nil;
        return;
    }
    ToolboxViewController *vc = [ToolboxViewController new];
    _sharedToolbox = vc;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    
    // iOS 15+ 底部 Sheet
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = nav.sheetPresentationController;
        if (sheet) {
            sheet.detents = @[
                [UISheetPresentationControllerDetent detentWithIdentifier:@"medium" resolvedBlock:^CGFloat(id<UserFloatEffectiveRange> _Nonnull context) {
                    return UIScreen.mainScreen.bounds.size.height * 0.55;
                }],
                [UISheetPresentationControllerDetent detentWithIdentifier:@"large" resolvedBlock:^CGFloat(id<UserFloatEffectiveRange> _Nonnull context) {
                    return UIScreen.mainScreen.bounds.size.height * 0.85;
                }]
            ];
            sheet.selectedDetentIdentifier = @"medium";
            sheet.prefersGrabberVisible = YES;
            sheet.largestUndimmedDetentIdentifier = @"large";
        }
    }

    UIViewController *root = [self _rootVC];
    [root presentViewController:nav animated:YES completion:nil];
}

+ (void)dismiss {
    [_sharedToolbox dismissViewControllerAnimated:YES completion:nil];
    _sharedToolbox = nil;
}

+ (BOOL)isVisible { return _sharedToolbox != nil; }

+ (UIViewController *)_rootVC {
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
    if (r) { while (r.presentedViewController) r = r.presentedViewController; }
    return r ?: [UIViewController new];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"🔧 Runtime 工具箱";
    self.view.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    
    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc] initWithTitle:@"✕" style:UIBarButtonItemStyleDone
                                                                target:self action:@selector(closeTapped)];
    closeBtn.tintColor = [UIColor lightGrayColor];
    self.navigationItem.leftBarButtonItem = closeBtn;

    // 内容区域
    CGFloat w = self.view.frame.size.width;
    CGFloat h = self.view.frame.size.height - 100;
    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.contentView];

    // Tab 栏
    [self setupTabs];
    [self buildSearchPanel];
    [self buildHooksPanel];
    [self buildProbePanel];
    [self buildDefaultsPanel];
    [self buildLogsPanel];
    [self switchToTab:0];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hookLogDidUpdate:)
                                                 name:HookLogDidUpdateNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)closeTapped { [ToolboxViewController dismiss]; }

#pragma mark - Tab

- (void)setupTabs {
    CGFloat w = self.contentView.frame.size.width;
    self.tabScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, 40)];
    self.tabScrollView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1];
    self.tabScrollView.showsHorizontalScrollIndicator = NO;
    self.tabScrollView.contentSize = CGSizeMake(w, 40);
    [self.contentView addSubview:self.tabScrollView];

    self.tabButtons = [NSMutableArray array];
    NSArray *tabs = @[@"🔍 搜索", @"🪝 Hook", @"📡 探测", @"⚙️ 默认值", @"📋 日志"];
    CGFloat tw = MAX(w / tabs.count, 70);
    for (int i = 0; i < tabs.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(i * tw, 0, tw, 40);
        [b setTitle:tabs[i] forState:UIControlStateNormal];
        [b setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        b.tag = i;
        [b addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.tabScrollView addSubview:b];
        [self.tabButtons addObject:b];
    }
    self.tabScrollView.contentSize = CGSizeMake(tw * tabs.count, 40);
}

- (void)tabTapped:(UIButton *)s { [self switchToTab:s.tag]; }

- (void)switchToTab:(NSInteger)tab {
    self.currentTab = tab;
    UIColor *activeColor = [UIColor colorWithRed:0.25 green:0.45 blue:0.85 alpha:1];
    for (UIView *v in self.contentView.subviews) {
        if (v.tag >= 1001 && v.tag <= 1005) v.hidden = (v.tag != 1001 + tab);
    }
    for (UIButton *b in self.tabButtons) {
        b.backgroundColor = [UIColor clearColor];
        b.tintColor = [UIColor grayColor];
    }
    UIButton *active = self.tabButtons[tab];
    active.backgroundColor = activeColor;
    active.tintColor = [UIColor whiteColor];

    if (tab == 1) [self refreshHooksList];
    else if (tab == 3) [self refreshDefaults];
    else if (tab == 4) [self refreshLogDisplay];
}

#pragma mark - 搜索

- (void)buildSearchPanel {
    CGFloat w = self.contentView.frame.size.width, h = self.contentView.frame.size.height;
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 40, w, h-40)]; v.tag = 1001;
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(10, 8, w-80, 34)];
    tf.placeholder = @"关键词 (vip, token...)"; tf.textColor = [UIColor whiteColor];
    tf.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1]; tf.layer.cornerRadius = 8;
    tf.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,8,0)]; tf.leftViewMode = UITextFieldViewModeAlways;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing; tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.autocorrectionType = UITextAutocorrectionTypeNo; tf.returnKeyType = UIReturnKeySearch;
    tf.font = [UIFont systemFontOfSize:14]; tf.delegate = self;
    [v addSubview:tf]; self.searchField = tf;

    UIButton *sb = [UIButton buttonWithType:UIButtonTypeSystem];
    sb.frame = CGRectMake(w-66, 8, 56, 34); [sb setTitle:@"搜索" forState:UIControlStateNormal];
    [sb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    sb.backgroundColor = [UIColor systemBlueColor]; sb.layer.cornerRadius = 8;
    sb.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [sb addTarget:self action:@selector(searchTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:sb];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.center = CGPointMake(w/2, h/2); self.spinner.hidesWhenStopped = YES;
    [v addSubview:self.spinner];

    self.resultView = [[UITextView alloc] initWithFrame:CGRectMake(6, 48, w-12, h-54)];
    self.resultView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    self.resultView.textColor = [UIColor colorWithRed:0.4 green:0.9 blue:0.4 alpha:1];
    self.resultView.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.resultView.editable = NO; self.resultView.layer.cornerRadius = 8;
    self.resultView.text = @"输入关键词搜索类和方法";
    [v addSubview:self.resultView];
    [self.contentView addSubview:v];
}

- (void)searchTapped {
    [self.searchField resignFirstResponder];
    NSString *kw = self.searchField.text;
    if (kw.length == 0) { self.resultView.text = @"请输入关键词"; return; }
    self.resultView.text = @""; [self.spinner startAnimating];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSString *r = [ClassDumpSearcher searchAndCopyWithKeyword:kw];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.resultView.text = r;
        });
    });
}

#pragma mark - Hook

- (void)buildHooksPanel {
    CGFloat w = self.contentView.frame.size.width, h = self.contentView.frame.size.height;
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 40, w, h-40)]; v.tag = 1002;

    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    addBtn.frame = CGRectMake(10, 4, w-20, 28);
    [addBtn setTitle:@"➕ 添加自定义 Hook" forState:UIControlStateNormal];
    [addBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    addBtn.backgroundColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.2 alpha:1];
    addBtn.layer.cornerRadius = 6; addBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [addBtn addTarget:self action:@selector(addHookTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:addBtn];

    CGFloat by = 36, bw = (w-36)/3;
    NSArray *tpl = @[@[@"🦸 VIP", @"VIPManager", @"isVIPMember"],
                     @[@"🦸 VIP", @"UserInfo", @"isVIP"],
                     @[@"🦸 VIP", @"SettingsManager", @"isPremium"],
                     @[@"🚫 广告", @"AdManager", @"shouldShowAd"],
                     @[@"🔓 解锁", @"PaywallManager", @"isLocked"]];
    for (int i = 0; i < (int)tpl.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(10+(i%3)*(bw+6), by+(i/3)*28, bw, 24);
        [b setTitle:tpl[i][0] forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.backgroundColor = [UIColor colorWithRed:0.25 green:0.35 blue:0.55 alpha:1];
        b.layer.cornerRadius = 5; b.titleLabel.font = [UIFont systemFontOfSize:10];
        objc_setAssociatedObject(b, "_cls", tpl[i][1], OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(b, "_sel", tpl[i][2], OBJC_ASSOCIATION_RETAIN);
        [b addTarget:self action:@selector(quickHookTapped:) forControlEvents:UIControlEventTouchUpInside];
        [v addSubview:b];
    }

    CGFloat tipY = by + ((int)tpl.count/3+1)*28 + 2;
    UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(10, tipY, w-20, 16)];
    tip.text = @"活跃 Hook（左滑取消）"; tip.textColor = [UIColor lightGrayColor]; tip.font = [UIFont systemFontOfSize:10];
    [v addSubview:tip];

    self.hooksTable = [[UITableView alloc] initWithFrame:CGRectMake(0, tipY+18, w, h-tipY-18) style:UITableViewStylePlain];
    self.hooksTable.backgroundColor = [UIColor clearColor]; self.hooksTable.dataSource = self;
    self.hooksTable.delegate = self; self.hooksTable.separatorColor = [UIColor colorWithWhite:0.3 alpha:0.5];
    [v addSubview:self.hooksTable];
    [self.contentView addSubview:v];
}

- (void)quickHookTapped:(UIButton *)s {
    NSString *c = objc_getAssociatedObject(s, "_cls"), *sel = objc_getAssociatedObject(s, "_sel");
    if (!c || !sel) return;
    BOOL yes = YES;
    if ([sel containsString:@"Ad"]||[sel containsString:@"ad"]||[sel containsString:@"Locked"]) yes = NO;
    BOOL ok = [MethodHacker hookMethodWithClass:c methodName:sel isClassMethod:NO returnType:@"BOOL" value:@(yes)];
    [self showToast:ok ? [NSString stringWithFormat:@"✅ %@.%@ → %@",c,sel,yes?@"YES":@"NO"] : [NSString stringWithFormat:@"❌ %@.%@ 失败",c,sel]];
    if (ok) [self refreshHooksList];
}

- (void)refreshHooksList { self.hooksList = [MethodHacker activeHooks]; [self.hooksTable reloadData]; }

- (void)addHookTapped {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"添加 Hook" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder = @"类名"; }];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder = @"方法名"; }];
    __block NSString *st = @"BOOL"; __block int ti = 0;
    [a addAction:[UIAlertAction actionWithTitle:@"类型: BOOL (切换)" style:UIAlertActionStyleDefault handler:^(id action){
        ti = (ti+1)%5; st = @[@"BOOL",@"id",@"NSInteger",@"double",@"void"][ti];
        [self addHookTapped];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(id action){
        NSString *c = [a.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSString *s = [a.textFields[1].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (c.length==0||s.length==0) return;
        id val = @YES;
        if ([st isEqualToString:@"id"]) val = @"(nil)";
        else if ([st isEqualToString:@"NSInteger"]) val = @0;
        else if ([st isEqualToString:@"double"]) val = @0.0;
        else if ([st isEqualToString:@"void"]) val = nil;
        BOOL ok = [MethodHacker hookMethodWithClass:c methodName:s isClassMethod:NO returnType:st value:val];
        [self showToast:ok ? [NSString stringWithFormat:@"✅ %@.%@",c,s] : [NSString stringWithFormat:@"❌ %@.%@ 失败",c,s]];
        if (ok) [self refreshHooksList];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

#pragma mark - 探测

- (void)buildProbePanel {
    CGFloat w = self.contentView.frame.size.width, h = self.contentView.frame.size.height;
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 40, w, h-40)]; v.tag = 1003;

    self.probeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.probeButton.frame = CGRectMake(10, 6, 80, 30);
    [self.probeButton setTitle:@"▶️ 开始探测" forState:UIControlStateNormal];
    [self.probeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.probeButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.3 alpha:1];
    self.probeButton.layer.cornerRadius = 6; self.probeButton.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [self.probeButton addTarget:self action:@selector(probeTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:self.probeButton];

    UIButton *vipBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    vipBtn.frame = CGRectMake(96, 6, 70, 30);
    [vipBtn setTitle:@"🦸 VIP分析" forState:UIControlStateNormal];
    [vipBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    vipBtn.backgroundColor = [UIColor colorWithRed:0.6 green:0.3 blue:0.1 alpha:1];
    vipBtn.layer.cornerRadius = 6; vipBtn.titleLabel.font = [UIFont boldSystemFontOfSize:10];
    [vipBtn addTarget:self action:@selector(probeVIPTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:vipBtn];

    self.probeProgress = [[UIProgressView alloc] initWithFrame:CGRectMake(172, 12, w-182, 4)];
    self.probeProgress.progressTintColor = [UIColor systemGreenColor]; self.probeProgress.hidden = YES;
    [v addSubview:self.probeProgress];

    self.probeStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(172, 18, w-182, 18)];
    self.probeStatusLabel.textColor = [UIColor lightGrayColor]; self.probeStatusLabel.font = [UIFont systemFontOfSize:10]; self.probeStatusLabel.hidden = YES;
    [v addSubview:self.probeStatusLabel];

    self.probeSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.probeSpinner.center = CGPointMake(w/2, h/2); self.probeSpinner.hidesWhenStopped = YES;
    [v addSubview:self.probeSpinner];

    self.probeResultView = [[UITextView alloc] initWithFrame:CGRectMake(6, 42, w-12, h-48)];
    self.probeResultView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    self.probeResultView.textColor = [UIColor colorWithRed:0.4 green:0.9 blue:0.4 alpha:1];
    self.probeResultView.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    self.probeResultView.editable = NO; self.probeResultView.layer.cornerRadius = 8;
    self.probeResultView.text = @"点击「开始探测」自动扫描关键词方法";
    [v addSubview:self.probeResultView];
    [self.contentView addSubview:v];
}

- (void)probeTapped {
    self.probeButton.enabled = NO; self.probeProgress.hidden = NO; self.probeProgress.progress = 0;
    self.probeStatusLabel.hidden = NO; self.probeStatusLabel.text = @"准备中...";
    self.probeResultView.text = @""; [self.probeSpinner startAnimating];
    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSArray *r = [ProbeEngine runProbeWithMaxClasses:300 progress:^(float p, NSString *c) {
            dispatch_async(dispatch_get_main_queue(), ^{
                ws.probeProgress.progress = p; ws.probeStatusLabel.text = [NSString stringWithFormat:@"%.0f%% %@",p*100,c];
            });
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            [ws.probeSpinner stopAnimating]; ws.probeButton.enabled = YES;
            ws.probeProgress.hidden = YES; ws.probeStatusLabel.hidden = YES;
            ws.probeResultView.text = [ProbeEngine formatReport:r];
            [UIPasteboard generalPasteboard].string = ws.probeResultView.text;
            [ws showToast:[NSString stringWithFormat:@"✅ 发现 %lu 项",(unsigned long)r.count]];
        });
    });
}

- (void)probeVIPTapped {
    self.probeButton.enabled = NO; self.probeResultView.text = @"VIP分析中..."; [self.probeSpinner startAnimating];
    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSArray *r = [ProbeEngine runProbeWithMaxClasses:300 progress:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            [ws.probeSpinner stopAnimating]; ws.probeButton.enabled = YES;
            ws.probeResultView.text = [ProbeEngine formatVIPReport:r];
            [UIPasteboard generalPasteboard].string = ws.probeResultView.text;
        });
    });
}

#pragma mark - 默认值

- (void)buildDefaultsPanel {
    CGFloat w = self.contentView.frame.size.width, h = self.contentView.frame.size.height;
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0,40,w,h-40)]; v.tag = 1004;

    self.defaultsSearchField = [[UITextField alloc] initWithFrame:CGRectMake(10, 8, w-20, 32)];
    self.defaultsSearchField.placeholder = @"搜索键名"; self.defaultsSearchField.textColor = [UIColor whiteColor];
    self.defaultsSearchField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    self.defaultsSearchField.layer.cornerRadius = 8; self.defaultsSearchField.font = [UIFont systemFontOfSize:13];
    self.defaultsSearchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,8,0)];
    self.defaultsSearchField.leftViewMode = UITextFieldViewModeAlways; self.defaultsSearchField.delegate = self;
    self.defaultsSearchField.tag = 2001;
    [self.defaultsSearchField addTarget:self action:@selector(defaultsSearchChanged) forControlEvents:UIControlEventEditingChanged];
    [v addSubview:self.defaultsSearchField];

    UIButton *copyB = [UIButton buttonWithType:UIButtonTypeSystem];
    copyB.frame = CGRectMake(w-56, 42, 44, 24); [copyB setTitle:@"📋" forState:UIControlStateNormal];
    [copyB setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyB.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1]; copyB.layer.cornerRadius = 6;
    [copyB addTarget:self action:@selector(copyDefaultsTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:copyB];

    UIButton *refB = [UIButton buttonWithType:UIButtonTypeSystem];
    refB.frame = CGRectMake(10, 42, 44, 24); [refB setTitle:@"🔄" forState:UIControlStateNormal];
    [refB setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    refB.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1]; refB.layer.cornerRadius = 6;
    [refB addTarget:self action:@selector(refreshDefaults) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:refB];

    self.defaultsTable = [[UITableView alloc] initWithFrame:CGRectMake(0, 70, w, h-70) style:UITableViewStylePlain];
    self.defaultsTable.backgroundColor = [UIColor clearColor]; self.defaultsTable.dataSource = self;
    self.defaultsTable.delegate = self; self.defaultsTable.tag = 3001;
    self.defaultsTable.separatorColor = [UIColor colorWithWhite:0.3 alpha:0.5];
    [v addSubview:self.defaultsTable];
    [self.contentView addSubview:v];
}

- (void)refreshDefaults {
    NSString *kw = self.defaultsSearchField.text;
    self.defaultsData = kw.length > 0 ? [UserDefaultsEditor searchDefaultsWithKeyword:kw] : [UserDefaultsEditor allDefaults];
    self.defaultsKeys = [self.defaultsData.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    [self.defaultsTable reloadData];
}
- (void)defaultsSearchChanged { [self refreshDefaults]; }
- (void)copyDefaultsTapped {
    NSString *r = [UserDefaultsEditor formatReport:self.defaultsData];
    [UIPasteboard generalPasteboard].string = r; [self showToast:@"✅ 已复制"];
}

#pragma mark - 日志

- (void)buildLogsPanel {
    CGFloat w = self.contentView.frame.size.width, h = self.contentView.frame.size.height;
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0,40,w,h-40)]; v.tag = 1005;

    self.clearLogButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clearLogButton.frame = CGRectMake(w-66, 4, 54, 24);
    [self.clearLogButton setTitle:@"🗑 清除" forState:UIControlStateNormal];
    [self.clearLogButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.clearLogButton.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1];
    self.clearLogButton.layer.cornerRadius = 5; self.clearLogButton.titleLabel.font = [UIFont systemFontOfSize:10];
    [self.clearLogButton addTarget:self action:@selector(clearLogTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:self.clearLogButton];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, w-80, 22)];
    lbl.text = @"📋 Hook 调用日志"; lbl.textColor = [UIColor lightGrayColor]; lbl.font = [UIFont systemFontOfSize:11];
    [v addSubview:lbl];

    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(6, 32, w-12, h-38)];
    self.logView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    self.logView.textColor = [UIColor colorWithRed:0.6 green:0.8 blue:1.0 alpha:1];
    self.logView.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    self.logView.editable = NO; self.logView.layer.cornerRadius = 8;
    self.logView.text = @"使用 Log 类型 Hook 后，调用记录显示在这里。";
    [v addSubview:self.logView];
    [self.contentView addSubview:v];
}

- (void)refreshLogDisplay {
    NSArray *logs = [MethodHacker hookLogs];
    self.logView.text = logs.count == 0 ? @"暂无记录" : [[logs reverseObjectEnumerator].allObjects componentsJoinedByString:@"\n"];
}
- (void)hookLogDidUpdate:(NSNotification *)note {
    if (self.currentTab == 4) [self refreshLogDisplay];
}
- (void)clearLogTapped { [MethodHacker clearLogs]; [self refreshLogDisplay]; [self showToast:@"✅ 已清除"]; }

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)section {
    return t == self.hooksTable ? MAX(self.hooksList.count,1) : MAX(self.defaultsKeys.count,1);
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:@"c"];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"c"];
        c.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
        c.textLabel.textColor = [UIColor whiteColor];
        c.detailTextLabel.textColor = [UIColor lightGrayColor];
        c.textLabel.font = [UIFont systemFontOfSize:12];
        c.detailTextLabel.font = [UIFont systemFontOfSize:10];
    }
    if (t == self.hooksTable) {
        if (self.hooksList.count == 0) { c.textLabel.text = @"暂无活跃 Hook"; c.detailTextLabel.text = nil; }
        else {
            ActiveHook *h = self.hooksList[ip.row];
            c.textLabel.text = [NSString stringWithFormat:@"%@.%@", h.className, h.methodName];
            c.detailTextLabel.text = [NSString stringWithFormat:@"→ %@ (调用%lu次)", h.returnValue?:@"void", (unsigned long)h.callCount];
        }
    } else {
        if (self.defaultsKeys.count == 0) { c.textLabel.text = @"无数据"; c.detailTextLabel.text = nil; }
        else {
            NSString *k = self.defaultsKeys[ip.row];
            id v = self.defaultsData[k];
            c.textLabel.text = k;
            c.detailTextLabel.text = [v isKindOfClass:NSData.class] ? [NSString stringWithFormat:@"<Data: %lu bytes>",(unsigned long)[(NSData*)v length]] : [NSString stringWithFormat:@"%@",v];
        }
    }
    return c;
}

- (BOOL)tableView:(UITableView *)t canEditRowAtIndexPath:(NSIndexPath *)ip {
    return (t == self.hooksTable && self.hooksList.count>0) || (t == self.defaultsTable && self.defaultsKeys.count>0);
}

- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)ed forRowAtIndexPath:(NSIndexPath *)ip {
    if (t == self.hooksTable) { [MethodHacker unhook:self.hooksList[ip.row]]; [self refreshHooksList]; }
    else { [UserDefaultsEditor removeKey:self.defaultsKeys[ip.row]]; [self refreshDefaults]; }
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    if (t == self.defaultsTable && self.defaultsKeys.count>0) {
        NSString *k = self.defaultsKeys[ip.row];
        UIAlertController *a = [UIAlertController alertControllerWithTitle:k message:@"新值" preferredStyle:UIAlertControllerStyleAlert];
        [a addTextFieldWithConfigurationHandler:^(UITextField *t2){ t2.text = [NSString stringWithFormat:@"%@",self.defaultsData[k]?:@""]; }];
        [a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(id action){
            [UserDefaultsEditor setValue:a.textFields[0].text forKey:k];
            [self refreshDefaults]; [self showToast:@"✅ 已保存"];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }
}

#pragma mark - 辅助

- (void)showToast:(NSString *)msg {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0,0,200,30)];
    l.center = CGPointMake(self.view.frame.size.width/2, 60);
    l.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85]; l.textColor = [UIColor whiteColor];
    l.textAlignment = NSTextAlignmentCenter; l.text = msg; l.layer.cornerRadius = 8;
    l.clipsToBounds = YES; l.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:l];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [l removeFromSuperview]; });
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)t {
    if (t == self.searchField) [self searchTapped];
    else if (t.tag == 2001) [self refreshDefaults];
    [t resignFirstResponder]; return YES;
}
@end

// ======== FloatingButton Implementation ========
@implementation FloatingButton

+ (instancetype)sharedButton {
    if (!_sharedFloatingButton) {
        CGFloat size = 44;
        _sharedFloatingButton = [[FloatingButton alloc] initWithFrame:CGRectMake(20, 120, size, size)];
        _sharedFloatingButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:0.85];
        _sharedFloatingButton.layer.cornerRadius = size/2;
        _sharedFloatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
        _sharedFloatingButton.layer.shadowOffset = CGSizeMake(0, 2);
        _sharedFloatingButton.layer.shadowOpacity = 0.4;
        _sharedFloatingButton.layer.shadowRadius = 4;
        _sharedFloatingButton.userInteractionEnabled = YES;

        // 图标
        UILabel *icon = [[UILabel alloc] initWithFrame:_sharedFloatingButton.bounds];
        icon.text = @"🔧";
        icon.textAlignment = NSTextAlignmentCenter;
        icon.font = [UIFont systemFontOfSize:20];
        icon.userInteractionEnabled = NO;
        [_sharedFloatingButton addSubview:icon];

        // 点击手势
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(buttonTapped)];
        [_sharedFloatingButton addGestureRecognizer:tap];

        // 拖拽手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(buttonDragged:)];
        [_sharedFloatingButton addGestureRecognizer:pan];
    }
    return _sharedFloatingButton;
}

+ (void)show {
    FloatingButton *btn = [self sharedButton];
    UIWindow *targetWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)s;
                if (ws.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *w in ws.windows) {
                        if (w.isKeyWindow) { targetWindow = w; break; }
                    }
                    if (!targetWindow) targetWindow = [ws.windows firstObject];
                    break;
                }
            }
        }
    }
    if (!targetWindow) targetWindow = [UIApplication sharedApplication].keyWindow;
    if (targetWindow && btn.superview != targetWindow) {
        [targetWindow addSubview:btn];
    }
    btn.hidden = NO;
    [[UIApplication sharedApplication].keyWindow bringSubviewToFront:btn];
}

+ (void)hide { _sharedFloatingButton.hidden = YES; }

+ (void)buttonTapped {
    if ([ToolboxViewController isVisible]) {
        [ToolboxViewController dismiss];
    } else {
        [ToolboxViewController show];
    }
}

+ (void)buttonDragged:(UIPanGestureRecognizer *)g {
    UIView *btn = g.view;
    CGPoint p = [g translationInView:btn.superview];
    CGPoint center = CGPointMake(btn.center.x + p.x, btn.center.y + p.y);
    
    // 边界约束
    CGFloat halfW = btn.frame.size.width/2;
    CGFloat halfH = btn.frame.size.height/2;
    CGFloat maxX = btn.superview.bounds.size.width - halfW;
    CGFloat maxY = btn.superview.bounds.size.height - halfH;
    center.x = MAX(halfW, MIN(maxX, center.x));
    center.y = MAX(halfH + 50, MIN(maxY, center.y)); // +50 避开状态栏
    
    btn.center = center;
    [g setTranslation:CGPointZero inView:btn.superview];
    
    if (g.state == UIGestureRecognizerStateEnded) {
        // 自动吸附到左右边缘
        CGFloat leftDist = center.x - halfW;
        CGFloat rightDist = maxX - center.x;
        CGFloat targetX = (leftDist < rightDist) ? halfW + 8 : maxX - 8;
        [UIView animateWithDuration:0.25 animations:^{
            btn.center = CGPointMake(targetX, btn.center.y);
        }];
    }
}

@end
