#import "TDPFloatingBall.h"
#import "TDPConfig.h"
#import "TDPVipEngine.h"
#import "TDPAdBlocker.h"

#pragma mark - Panel Controller

@interface TDPPanelController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, copy) void (^onClose)(void);
- (void)refreshLog;
@end

@implementation TDPPanelController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.96];
    self.title = @"巨魔工具箱";

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setTitle:@"关闭" forState:UIControlStateNormal];
    close.tintColor = UIColor.whiteColor;
    [close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:close];

    CGFloat top = 0;
    if (@available(iOS 11.0, *)) {
        // table 用 constraints
    }

    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    _table.delegate = self;
    _table.dataSource = self;
    _table.backgroundColor = UIColor.clearColor;
    _table.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        _table.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
    [self.view addSubview:_table];

    _logView = [[UITextView alloc] initWithFrame:CGRectZero];
    _logView.editable = NO;
    _logView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    _logView.textColor = [UIColor colorWithRed:0.6 green:1 blue:0.7 alpha:1];
    _logView.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    _logView.translatesAutoresizingMaskIntoConstraints = NO;
    _logView.text = @"日志";
    [self.view addSubview:_logView];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_table.topAnchor constraintEqualToAnchor:g.topAnchor],
        [_table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_table.heightAnchor constraintEqualToAnchor:self.view.heightAnchor multiplier:0.55],

        [_logView.topAnchor constraintEqualToAnchor:_table.bottomAnchor constant:4],
        [_logView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [_logView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [_logView.bottomAnchor constraintEqualToAnchor:g.bottomAnchor constant:-8],
    ]];

    [self refreshLog];
    (void)top;
}

- (void)closeTapped {
    if (self.onClose) self.onClose();
}

- (void)refreshLog {
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"—— 会员 ——\n%@\n\n", [TDPVipEngine.shared statusText]];
    [s appendFormat:@"—— 广告 ——\n%@\n", [TDPAdBlocker.shared statusText]];
    self.logView.text = s;
}

#pragma mark Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 4;
    if (section == 1) return 3;
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"开关";
    if (section == 1) return @"会员操作";
    return @"广告操作";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) {
        return @"仅对「本地判断会员」的 App 可能有效。服务端校验、登录态加密、IAP 收据验证无法本地改成真会员。";
    }
    if (section == 2) {
        return @"通过隐藏广告视图 + Hook 常见广告 SDK 加载方法。无法保证覆盖所有广告联盟。";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"c";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
        cell.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
        cell.textLabel.textColor = UIColor.whiteColor;
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.detailTextLabel.text = nil;

    TDPConfig *cfg = TDPConfig.shared;

    if (ip.section == 0) {
        UISwitch *sw = [[UISwitch alloc] init];
        void (^bind)(BOOL on, void(^set)(BOOL)) = ^(BOOL on, void(^set)(BOOL)) {
            sw.on = on;
        };
        if (ip.row == 0) {
            cell.textLabel.text = @"显示悬浮球";
            bind(cfg.showFloatingBall, nil);
            sw.on = cfg.showFloatingBall;
            sw.tag = 100;
        } else if (ip.row == 1) {
            cell.textLabel.text = @"强制会员（启发式）";
            cell.detailTextLabel.text = @"写入本地标记 + Hook isVip 等";
            sw.on = cfg.forceVip;
            sw.tag = 101;
        } else if (ip.row == 2) {
            cell.textLabel.text = @"去广告";
            sw.on = cfg.blockAds;
            sw.tag = 102;
        } else {
            cell.textLabel.text = @"启动自动应用";
            cell.detailTextLabel.text = @"打开 App 后按开关自动执行";
            sw.on = cfg.autoApply;
            sw.tag = 103;
        }
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    } else if (ip.section == 1) {
        if (ip.row == 0) {
            cell.textLabel.text = @"扫描会员状态";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        } else if (ip.row == 1) {
            cell.textLabel.text = @"立即应用强制会员";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        } else {
            cell.textLabel.text = @"查看扫描明细";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
    } else {
        if (ip.row == 0) {
            cell.textLabel.text = @"立即清理广告视图";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        } else {
            cell.textLabel.text = @"重新安装广告 Hook";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
    }
    return cell;
}

- (void)switchChanged:(UISwitch *)sw {
    TDPConfig *cfg = TDPConfig.shared;
    switch (sw.tag) {
        case 100:
            cfg.showFloatingBall = sw.on;
            [TDPFloatingBall.shared setVisible:sw.on];
            break;
        case 101:
            cfg.forceVip = sw.on;
            if (sw.on) {
                [TDPVipEngine.shared applyForceVip];
                [TDPFloatingBall.shared toast:@"已尝试强制会员"];
            } else {
                [TDPFloatingBall.shared toast:@"已关闭强制会员（需杀进程才完全恢复）"];
            }
            break;
        case 102:
            cfg.blockAds = sw.on;
            if (sw.on) {
                [TDPAdBlocker.shared install];
                [TDPFloatingBall.shared toast:@"去广告已开启"];
            } else {
                [TDPFloatingBall.shared toast:@"去广告已关闭（已显示视图需重进页面）"];
            }
            break;
        case 103:
            cfg.autoApply = sw.on;
            break;
        default: break;
    }
    [self refreshLog];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tableView deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 1) {
        if (ip.row == 0) {
            [TDPVipEngine.shared scan];
            [TDPFloatingBall.shared toast:@"扫描完成"];
            [self refreshLog];
        } else if (ip.row == 1) {
            TDPConfig.shared.forceVip = YES;
            [TDPVipEngine.shared applyForceVip];
            [self.table reloadData];
            [TDPFloatingBall.shared toast:@"已应用强制会员"];
            [self refreshLog];
        } else {
            [self showHitDetails];
        }
    } else if (ip.section == 2) {
        if (ip.row == 0) {
            NSInteger n = [TDPAdBlocker.shared scrubVisibleAds];
            [TDPFloatingBall.shared toast:[NSString stringWithFormat:@"隐藏 %ld 个视图", (long)n]];
            [self refreshLog];
        } else {
            [TDPAdBlocker.shared install];
            [TDPFloatingBall.shared toast:@"广告 Hook 已刷新"];
            [self refreshLog];
        }
    }
}

- (void)showHitDetails {
    NSArray<TDPVipHit *> *hits = TDPVipEngine.shared.lastHits;
    if (hits.count == 0) {
        [TDPVipEngine.shared scan];
        hits = TDPVipEngine.shared.lastHits;
    }
    NSMutableString *msg = [NSMutableString string];
    NSInteger limit = MIN((NSInteger)hits.count, 40);
    for (NSInteger i = 0; i < limit; i++) {
        TDPVipHit *h = hits[i];
        [msg appendFormat:@"[%@] %@ = %@%@\n",
         h.source, h.name, h.valueDescription ?: @"",
         h.looksLikeVipTrue ? @" ✅" : @""];
    }
    if (hits.count > 40) {
        [msg appendFormat:@"\n… 共 %ld 条，仅显示前 40", (long)hits.count];
    }
    if (msg.length == 0) msg.string = @"未发现可疑项";

    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"扫描明细"
                                                               message:msg
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

@end

#pragma mark - Floating Ball

@interface TDPFloatingBall ()
@property (nonatomic, strong) UIWindow *ballWindow;
@property (nonatomic, strong) UIButton *ballButton;
@property (nonatomic, strong) UIWindow *panelWindow;
@property (nonatomic, assign) BOOL started;
@end

@implementation TDPFloatingBall

+ (instancetype)shared {
    static TDPFloatingBall *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[TDPFloatingBall alloc] init]; });
    return s;
}

- (void)startIfNeeded {
    if (self.started) {
        [self setVisible:TDPConfig.shared.showFloatingBall];
        return;
    }
    self.started = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self buildBallWindow];
        [self setVisible:TDPConfig.shared.showFloatingBall];
    });
}

- (UIWindowScene *)activeScene API_AVAILABLE(ios(13.0)) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:[UIWindowScene class]]) {
            return (UIWindowScene *)scene;
        }
    }
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) return (UIWindowScene *)scene;
    }
    return nil;
}

- (void)buildBallWindow {
    @try {
        if (![UIApplication sharedApplication]) return;

        CGFloat size = 56;
        CGRect screen = UIScreen.mainScreen.bounds;
        if (CGRectIsEmpty(screen) || screen.size.width < 1) return;

        CGRect frame = CGRectMake(screen.size.width - size - 12,
                                  screen.size.height * 0.55,
                                  size, size);

        UIWindow *win = nil;
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = [self activeScene];
            if (scene) {
                win = [[UIWindow alloc] initWithWindowScene:scene];
            }
        }
        if (!win) {
            win = [[UIWindow alloc] initWithFrame:frame];
        } else {
            win.frame = frame;
        }

        win.windowLevel = UIWindowLevelStatusBar + 120;
        win.backgroundColor = UIColor.clearColor;
        win.clipsToBounds = NO;
        // 只 hidden=NO，绝不 makeKeyAndVisible
        win.hidden = NO;
        win.userInteractionEnabled = YES;

        UIViewController *root = [UIViewController new];
        root.view.backgroundColor = UIColor.clearColor;
        win.rootViewController = root;

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(0, 0, size, size);
        btn.layer.cornerRadius = size / 2;
        btn.backgroundColor = [UIColor colorWithRed:0.15 green:0.55 blue:1 alpha:0.92];
        btn.layer.shadowColor = UIColor.blackColor.CGColor;
        btn.layer.shadowOpacity = 0.35;
        btn.layer.shadowRadius = 6;
        btn.layer.shadowOffset = CGSizeMake(0, 3);
        [btn setTitle:@"魔" forState:UIControlStateNormal];
        [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
        [btn addTarget:self action:@selector(ballTapped) forControlEvents:UIControlEventTouchUpInside];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(ballPanned:)];
        [btn addGestureRecognizer:pan];

        [root.view addSubview:btn];
        self.ballButton = btn;
        self.ballWindow = win;
    } @catch (NSException *e) {
        NSLog(@"[TrollDylibPlugin] buildBallWindow exception: %@", e);
        self.ballWindow = nil;
    }
}

- (void)setVisible:(BOOL)visible {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!self.ballWindow) {
                if (visible) [self buildBallWindow];
            }
            self.ballWindow.hidden = !visible;
            if (visible && self.ballWindow) {
                // 禁止 makeKeyAndVisible：多 App 会因此闪退
                self.ballWindow.windowLevel = UIWindowLevelStatusBar + 120;
                self.ballWindow.hidden = NO;
            }
        } @catch (NSException *e) {
            NSLog(@"[TrollDylibPlugin] setVisible exception: %@", e);
        }
    });
}

- (void)ballPanned:(UIPanGestureRecognizer *)pan {
    UIWindow *win = self.ballWindow;
    CGPoint t = [pan translationInView:win];
    CGRect f = win.frame;
    f.origin.x += t.x;
    f.origin.y += t.y;
    CGRect screen = UIScreen.mainScreen.bounds;
    f.origin.x = MAX(0, MIN(screen.size.width - f.size.width, f.origin.x));
    f.origin.y = MAX(40, MIN(screen.size.height - f.size.height - 20, f.origin.y));
    win.frame = f;
    [pan setTranslation:CGPointZero inView:win];

    if (pan.state == UIGestureRecognizerStateEnded) {
        // 吸附左右
        CGFloat mid = CGRectGetMidX(f);
        [UIView animateWithDuration:0.2 animations:^{
            CGRect nf = win.frame;
            nf.origin.x = (mid < screen.size.width / 2.0) ? 8 : (screen.size.width - nf.size.width - 8);
            win.frame = nf;
        }];
    }
}

- (void)ballTapped {
    [self showPanel];
}

- (void)showPanel {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.panelWindow && !self.panelWindow.hidden) return;

        CGRect screen = UIScreen.mainScreen.bounds;
        UIWindow *win = nil;
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = [self activeScene];
            if (scene) win = [[UIWindow alloc] initWithWindowScene:scene];
        }
        if (!win) win = [[UIWindow alloc] initWithFrame:screen];
        else win.frame = screen;

        win.windowLevel = UIWindowLevelStatusBar + 200;
        win.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];

        TDPPanelController *panel = [TDPPanelController new];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:panel];
        if (@available(iOS 13.0, *)) {
            nav.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
            nav.navigationBar.barStyle = UIBarStyleBlack;
        }
        nav.view.layer.cornerRadius = 14;
        nav.view.clipsToBounds = YES;

        UIViewController *root = [UIViewController new];
        root.view.backgroundColor = UIColor.clearColor;
        [root addChildViewController:nav];
        [root.view addSubview:nav.view];
        nav.view.translatesAutoresizingMaskIntoConstraints = NO;
        UILayoutGuide *g = root.view.safeAreaLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [nav.view.centerXAnchor constraintEqualToAnchor:root.view.centerXAnchor],
            [nav.view.centerYAnchor constraintEqualToAnchor:root.view.centerYAnchor],
            [nav.view.widthAnchor constraintEqualToAnchor:root.view.widthAnchor multiplier:0.9],
            [nav.view.heightAnchor constraintEqualToAnchor:root.view.heightAnchor multiplier:0.78],
        ]];
        [nav didMoveToParentViewController:root];

        __weak typeof(self) weakSelf = self;
        panel.onClose = ^{
            [weakSelf hidePanel];
        };

        // 点半透明背景关闭
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backdropTapped:)];
        tap.cancelsTouchesInView = NO;
        [root.view addGestureRecognizer:tap];

        win.rootViewController = root;
        // 禁止 makeKeyAndVisible，防止抢焦点闪退
        win.hidden = NO;
        self.panelWindow = win;
    });
}

- (void)backdropTapped:(UITapGestureRecognizer *)tap {
    CGPoint p = [tap locationInView:tap.view];
    UIView *navView = tap.view.subviews.firstObject;
    if (navView && CGRectContainsPoint(navView.frame, p)) return;
    [self hidePanel];
}

- (void)hidePanel {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            self.panelWindow.hidden = YES;
            self.panelWindow.rootViewController = nil;
            self.panelWindow = nil;
            if (TDPConfig.shared.showFloatingBall && self.ballWindow) {
                self.ballWindow.hidden = NO;
            }
        } @catch (__unused NSException *e) {
            self.panelWindow = nil;
        }
    });
}

- (void)toast:(NSString *)message {
    if (!TDPConfig.shared.toastEnabled) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *host = self.panelWindow && !self.panelWindow.hidden ? self.panelWindow : self.ballWindow;
        UIView *parent = host.rootViewController.view ?: host;
        UILabel *lab = [[UILabel alloc] init];
        lab.text = message;
        lab.textColor = UIColor.whiteColor;
        lab.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.88];
        lab.font = [UIFont systemFontOfSize:13];
        lab.textAlignment = NSTextAlignmentCenter;
        lab.numberOfLines = 0;
        lab.layer.cornerRadius = 10;
        lab.clipsToBounds = YES;
        CGSize size = [lab sizeThatFits:CGSizeMake(parent.bounds.size.width - 40, 200)];
        lab.frame = CGRectMake(20, parent.bounds.size.height * 0.18, parent.bounds.size.width - 40, size.height + 16);
        lab.alpha = 0;
        [parent addSubview:lab];
        [UIView animateWithDuration:0.2 animations:^{ lab.alpha = 1; } completion:^(__unused BOOL f) {
            [UIView animateWithDuration:0.3 delay:1.4 options:0 animations:^{ lab.alpha = 0; } completion:^(__unused BOOL f2) {
                [lab removeFromSuperview];
            }];
        }];
    });
}

@end
