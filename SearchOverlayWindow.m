#import "SearchOverlayWindow.h"
#import "ClassDumpSearcher.h"
#import "MethodHacker.h"
#import "UserDefaultsEditor.h"
#import <objc/runtime.h>  // 用于 objc_setAssociatedObject / objc_getAssociatedObject

typedef NS_ENUM(NSUInteger, OverlayTab) {
    OverlayTabSearch   = 0,
    OverlayTabHooks    = 1,
    OverlayTabDefaults = 2
};

@interface SearchOverlayWindow () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UIView *contentArea;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, assign) OverlayTab currentTab;
@property (nonatomic, strong) UIButton *tabSearchBtn;
@property (nonatomic, strong) UIButton *tabHooksBtn;
@property (nonatomic, strong) UIButton *tabDefaultsBtn;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UITextView *resultView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UITableView *hooksTable;
@property (nonatomic, strong) UIButton *addHookButton;
@property (nonatomic, strong) NSArray<ActiveHook *> *hooksList;
@property (nonatomic, strong) UITextField *defaultsSearchField;
@property (nonatomic, strong) UITableView *defaultsTable;
@property (nonatomic, strong) NSDictionary *defaultsData;
@property (nonatomic, strong) NSArray *defaultsKeys;
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
    CGFloat panelH = MIN([UIScreen mainScreen].bounds.size.height - 80, 680);
    CGFloat ox = ([UIScreen mainScreen].bounds.size.width - panelW) / 2;
    CGFloat oy = 50;

    UIButton *bg = [UIButton buttonWithType:UIButtonTypeCustom];
    bg.frame = self.bounds;
    bg.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.35];
    [bg addTarget:self action:@selector(dismissTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:bg];

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(ox, oy, panelW, panelH)];
    panel.tag = 9999;
    panel.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.96];
    panel.layer.cornerRadius = 16;
    panel.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1].CGColor;
    panel.layer.borderWidth = 0.5;
    panel.clipsToBounds = YES;
    [self addSubview:panel];
    self.panelView = panel;

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

    CGFloat contentY = 44;
    CGFloat contentH = panelH - contentY - 50;
    self.contentArea = [[UIView alloc] initWithFrame:CGRectMake(0, contentY, panelW, contentH)];
    self.contentArea.backgroundColor = [UIColor clearColor];
    [panel addSubview:self.contentArea];

    CGFloat tabY = panelH - 44;
    UIView *tabBar = [[UIView alloc] initWithFrame:CGRectMake(0, tabY, panelW, 44)];
    tabBar.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1];
    tabBar.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1].CGColor;
    tabBar.layer.borderWidth = 0.5;
    [panel addSubview:tabBar];

    CGFloat tw = panelW / 3;
    self.tabSearchBtn = [self tabBtn:CGRectMake(0, 0, tw, 44) t:@"🔍 搜索" tag:OverlayTabSearch];
    self.tabHooksBtn  = [self tabBtn:CGRectMake(tw, 0, tw, 44) t:@"🪝 Hook" tag:OverlayTabHooks];
    self.tabDefaultsBtn = [self tabBtn:CGRectMake(tw*2, 0, tw, 44) t:@"⚙️ 默认值" tag:OverlayTabDefaults];
    [tabBar addSubview:self.tabSearchBtn];
    [tabBar addSubview:self.tabHooksBtn];
    [tabBar addSubview:self.tabDefaultsBtn];

    [self buildSearchPanel];
    [self buildHooksPanel];
    [self buildDefaultsPanel];
    [self switchToTab:OverlayTabSearch];
}

- (UIButton *)tabBtn:(CGRect)frame t:(NSString *)title tag:(OverlayTab)tag {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = frame; [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:13]; b.tag = tag;
    [b addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)tabTapped:(UIButton *)s { [self switchToTab:(OverlayTab)s.tag]; }

- (void)switchToTab:(OverlayTab)tab {
    self.currentTab = tab;
    for (UIView *v in self.contentArea.subviews) v.hidden = YES;
    for (UIButton *b in @[self.tabSearchBtn, self.tabHooksBtn, self.tabDefaultsBtn]) {
        [b setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        b.backgroundColor = [UIColor clearColor];
    }
    UIView *tv = nil;
    UIColor *ac = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1];
    if (tab == OverlayTabSearch) { tv = [self.contentArea viewWithTag:1001]; self.tabSearchBtn.backgroundColor = ac; [self.tabSearchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; }
    else if (tab == OverlayTabHooks) { tv = [self.contentArea viewWithTag:1002]; self.tabHooksBtn.backgroundColor = ac; [self.tabHooksBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; [self refreshHooksList]; }
    else if (tab == OverlayTabDefaults) { tv = [self.contentArea viewWithTag:1003]; self.tabDefaultsBtn.backgroundColor = ac; [self.tabDefaultsBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; [self refreshDefaults]; }
    tv.hidden = NO;
}

#pragma mark - 搜索面板

- (void)buildSearchPanel {
    CGFloat w = self.contentArea.frame.size.width, h = self.contentArea.frame.size.height;
    UIView *v = [[UIView alloc] initWithFrame:self.contentArea.bounds]; v.tag = 1001;
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(12, 8, w-90, 34)];
    tf.placeholder = @"关键词（vip, token...）"; tf.textColor = [UIColor whiteColor];
    tf.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1]; tf.layer.cornerRadius = 8;
    tf.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 0)]; tf.leftViewMode = UITextFieldViewModeAlways;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing; tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
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

    UIButton *hb = [UIButton buttonWithType:UIButtonTypeSystem];
    hb.frame = CGRectMake(12, 46, 70, 26); [hb setTitle:@"⚡ Hook" forState:UIControlStateNormal];
    [hb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    hb.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.3 alpha:1];
    hb.layer.cornerRadius = 6; hb.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [hb addTarget:self action:@selector(hookFromSearchTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:hb];

    UIButton *cb = [UIButton buttonWithType:UIButtonTypeSystem];
    cb.frame = CGRectMake(88, 46, 70, 26); [cb setTitle:@"📋 复制" forState:UIControlStateNormal];
    [cb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    cb.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1]; cb.layer.cornerRadius = 6;
    cb.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [cb addTarget:self action:@selector(copySearchResultTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:cb];

    UIActivityIndicatorView *sp = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    sp.center = CGPointMake(w/2, h/2); sp.hidesWhenStopped = YES;
    [v addSubview:sp]; self.spinner = sp;

    UITextView *tv = [[UITextView alloc] initWithFrame:CGRectMake(6, 76, w-12, h-82)];
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
        // searchAndCopyWithKeyword: 现在已在 ClassDumpSearcher 中实现
        NSString *r = [ClassDumpSearcher searchAndCopyWithKeyword:kw];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating]; self.searchButton.enabled = YES;
            self.resultView.text = r; [self.resultView scrollRangeToVisible:NSMakeRange(0, 0)];
            [self showToast:@"✅ 已复制到剪贴板"];
        });
    });
}

- (void)hookFromSearchTapped {
    NSString *kw = self.searchField.text;
    if (kw.length == 0) { [self showToast:@"⚠️ 先输入关键词搜索"]; return; }
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"⚡ Hook 方法" message:@"输入类名和方法名" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder = @"类名"; t.autocapitalizationType = UITextAutocapitalizationTypeNone; }];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder = @"方法名"; t.text = kw; t.autocapitalizationType = UITextAutocapitalizationTypeNone; }];
    [a addAction:[UIAlertAction actionWithTitle:@"Hook → YES" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        NSString *c = a.textFields[0].text, *s = a.textFields[1].text;
        if (c.length && s.length) {
            BOOL ok = [MethodHacker hookMethodWithClass:c methodName:s isClassMethod:NO returnType:@"BOOL" value:@YES];
            [self showToast:ok ? @"✅ Hook 成功" : @"❌ 失败"]; if (ok) [self refreshHooksList];
        }
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Hook → NO" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
        NSString *c = a.textFields[0].text, *s = a.textFields[1].text;
        if (c.length && s.length) {
            BOOL ok = [MethodHacker hookMethodWithClass:c methodName:s isClassMethod:NO returnType:@"BOOL" value:@NO];
            [self showToast:ok ? @"✅ Hook 成功" : @"❌ 失败"]; if (ok) [self refreshHooksList];
        }
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [[self viewControllerForPresent] presentViewController:a animated:YES completion:nil];
}

- (void)copySearchResultTapped {
    if (self.resultView.text.length > 0) {
        [UIPasteboard generalPasteboard].string = self.resultView.text;
        [self showToast:@"✅ 已复制"];
    }
}

#pragma mark - Hooks 面板

- (void)buildHooksPanel {
    CGFloat w = self.contentArea.frame.size.width, h = self.contentArea.frame.size.height;
    UIView *view = [[UIView alloc] initWithFrame:self.contentArea.bounds]; view.tag = 1002;

    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    addBtn.frame = CGRectMake(12, 4, w-24, 32);
    [addBtn setTitle:@"➕ 自定义 Hook" forState:UIControlStateNormal];
    [addBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    addBtn.backgroundColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.2 alpha:1];
    addBtn.layer.cornerRadius = 8; addBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [addBtn addTarget:self action:@selector(addHookTapped) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:addBtn]; self.addHookButton = addBtn;

    CGFloat by = 40, bw = (w-36)/3;
    NSArray *tpl = @[@[@"🦸 VIP解锁", @"VIPManager", @"isVIPMember"],
                     @[@"🦸 VIP解锁", @"UserInfo", @"isVIP"],
                     @[@"🦸 VIP解锁", @"SettingsManager", @"isPremium"],
                     @[@"🚫 去广告", @"AdManager", @"shouldShowAd"],
                     @[@"🚫 去广告", @"ADManager", @"isAd"],
                     @[@"🚫 去广告", @"BannerView", @"canDisplayAd"],
                     @[@"🔓 全解锁", @"PaywallManager", @"isLocked"],
                     @[@"🔓 全解锁", @"FeatureManager", @"hasAccess"]];
    for (int i = 0; i < (int)tpl.count; i++) {
        NSArray *t = tpl[i];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(12+(i%3)*(bw+6), by+(i/3)*30, bw, 26);
        [b setTitle:t[0] forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.backgroundColor = [UIColor colorWithRed:0.25 green:0.35 blue:0.55 alpha:1];
        b.layer.cornerRadius = 6; b.titleLabel.font = [UIFont systemFontOfSize:10];
        objc_setAssociatedObject(b, "_hook_cls", t[1], OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(b, "_hook_sel", t[2], OBJC_ASSOCIATION_RETAIN);
        [b addTarget:self action:@selector(quickHookTapped:) forControlEvents:UIControlEventTouchUpInside];
        [view addSubview:b];
    }

    CGFloat tipY = by + ((tpl.count+2)/3)*30 + 4;
    UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(12, tipY, w-24, 18)];
    tip.text = @"活跃的 Hook（左滑取消）"; tip.textColor = [UIColor lightGrayColor]; tip.font = [UIFont systemFontOfSize:11];
    [view addSubview:tip];

    CGFloat tY = tipY + 20;
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
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"添加 Hook" message:@"输入类名与方法名\n如: VIPManager isVIPMember" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder = @"类名（如 VIPManager）"; t.autocapitalizationType = UITextAutocapitalizationTypeNone; }];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder = @"方法名（如 isVIPMember）"; t.autocapitalizationType = UITextAutocapitalizationTypeNone; }];
    __block NSString *st = @"BOOL"; __block int ti = 0;
    [a addAction:[UIAlertAction actionWithTitle:@"返回类型: BOOL (点我切换)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        ti = (ti+1)%5;
        NSArray *ts = @[@"BOOL",@"id",@"NSInteger",@"double",@"void"];
        st = ts[ti];
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
        else if ([st isEqualToString:@"void"]) val = nil;
        BOOL ok = [MethodHacker hookMethodWithClass:c methodName:s isClassMethod:NO returnType:st value:val];
        [self showToast:ok ? [NSString stringWithFormat:@"✅ Hook %@.%@",c,s] : [NSString stringWithFormat:@"❌ Hook 失败: %@.%@",c,s]];
        if (ok) [self refreshHooksList];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [[self viewControllerForPresent] presentViewController:a animated:YES completion:nil];
}

#pragma mark - Defaults 面板

- (void)buildDefaultsPanel {
    CGFloat w = self.contentArea.frame.size.width, h = self.contentArea.frame.size.height;
    UIView *view = [[UIView alloc] initWithFrame:self.contentArea.bounds]; view.tag = 1003;

    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(12, 8, w-24, 34)];
    tf.placeholder = @"搜索键名（留空显示全部）"; tf.textColor = [UIColor whiteColor];
    tf.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1]; tf.layer.cornerRadius = 8;
    tf.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 0)]; tf.leftViewMode = UITextFieldViewModeAlways;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing; tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.autocorrectionType = UITextAutocorrectionTypeNo; tf.returnKeyType = UIReturnKeySearch;
    tf.font = [UIFont systemFontOfSize:14]; tf.delegate = self; tf.tag = 2001;
    [tf addTarget:self action:@selector(defaultsSearchChanged) forControlEvents:UIControlEventEditingChanged];
    [view addSubview:tf]; self.defaultsSearchField = tf;

    UIButton *copyB = [UIButton buttonWithType:UIButtonTypeSystem];
    copyB.frame = CGRectMake(w-60, 44, 48, 28);
    [copyB setTitle:@"📋" forState:UIControlStateNormal];
    [copyB setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyB.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1];
    copyB.layer.cornerRadius = 6; copyB.titleLabel.font = [UIFont systemFontOfSize:14];
    [copyB addTarget:self action:@selector(copyDefaultsTapped) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:copyB];

    UIButton *refB = [UIButton buttonWithType:UIButtonTypeSystem];
    refB.frame = CGRectMake(12, 44, 48, 28);
    [refB setTitle:@"🔄" forState:UIControlStateNormal];
    [refB setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    refB.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1];
    refB.layer.cornerRadius = 6; refB.titleLabel.font = [UIFont systemFontOfSize:14];
    [refB addTarget:self action:@selector(refreshDefaults) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:refB];

    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 76, w, h-76) style:UITableViewStylePlain];
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

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)section {
    return t == self.hooksTable ? MAX(self.hooksList.count,1) : MAX(self.defaultsKeys.count,1);
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:@"cell"];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
        c.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
        c.textLabel.textColor = [UIColor whiteColor];
        c.detailTextLabel.textColor = [UIColor lightGrayColor];
        c.textLabel.font = [UIFont systemFontOfSize:13];
        c.detailTextLabel.font = [UIFont systemFontOfSize:11];
        c.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    if (t == self.hooksTable) {
        if (self.hooksList.count == 0) { c.textLabel.text = @"暂无活跃 Hook"; c.detailTextLabel.text = @"点击上方按钮添加"; }
        else { ActiveHook *h = self.hooksList[ip.row]; c.textLabel.text = [NSString stringWithFormat:@"%@.%@",h.className,h.methodName]; c.detailTextLabel.text = [NSString stringWithFormat:@"→ %@ (%@)",h.returnValue?:@"void",h.returnType]; }
    } else {
        if (self.defaultsKeys.count == 0) { c.textLabel.text = @"无数据"; c.detailTextLabel.text = @"没有找到 UserDefaults 记录"; }
        else { NSString *k = self.defaultsKeys[ip.row]; id v = self.defaultsData[k]; c.textLabel.text = k; c.detailTextLabel.text = [v isKindOfClass:NSData.class] ? [NSString stringWithFormat:@"<Data: %lu bytes>",(unsigned long)[(NSData*)v length]] : [NSString stringWithFormat:@"%@",v]; }
    }
    return c;
}

- (BOOL)tableView:(UITableView *)t canEditRowAtIndexPath:(NSIndexPath *)ip {
    return (t == self.hooksTable && self.hooksList.count > 0) || (t == self.defaultsTable && self.defaultsKeys.count > 0);
}

- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)ed forRowAtIndexPath:(NSIndexPath *)ip {
    if (t == self.hooksTable) {
        // unhook: 现在已在 MethodHacker 中实现
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
    UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"编辑: %@",key] message:@"输入新值（NSString）" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.text = [NSString stringWithFormat:@"%@",value?:@""]; t.placeholder = @"新值"; }];
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
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 220, 34)];
    t.center = CGPointMake(self.panelView.frame.size.width/2, self.panelView.frame.size.height/2-20);
    t.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85]; t.textColor = [UIColor whiteColor];
    t.textAlignment = NSTextAlignmentCenter; t.text = msg; t.layer.cornerRadius = 8;
    t.clipsToBounds = YES; t.font = [UIFont systemFontOfSize:13];
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
