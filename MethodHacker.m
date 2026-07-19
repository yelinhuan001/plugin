### 1. 配置文件：`Makefile`
**文件名：`Makefile`** (放在项目根目录)
```makefile
PROJECT = ClassDumpDylib
OUTDIR  = packages
FILES   = ClassDumpEntry.m ClassDumpSearcher.m SearchOverlayWindow.m MethodHacker.m UserDefaultsEditor.m

# 编译参数：强制包含 Foundation 和 UIKit
CFLAGS  = -fobjc-arc -I. -O2 -Wall
LDFLAGS = -dynamiclib -lobjc \
          -framework UIKit \
          -framework Foundation \
          -framework QuartzCore \
          -framework CoreGraphics

ARCHS   = -arch arm64 -arch arm64e

# 自动获取 SDK 路径
SDK_PATH = $(shell xcrun --sdk iphoneos --show-sdk-path)

all: $(OUTDIR)/$(PROJECT).dylib

$(OUTDIR)/$(PROJECT).dylib: $(FILES)
	@mkdir -p $(OUTDIR)
	@echo "——> 正在使用 SDK 编译: $(SDK_PATH)"
	clang $(ARCHS) $(CFLAGS) \
		-isysroot "$(SDK_PATH)" \
		-miphoneos-version-min=14.0 \
		$(LDFLAGS) \
		$(FILES) \
		-o $(OUTDIR)/$(PROJECT).dylib
	@echo " 编译成功！产物在: $(OUTDIR)/$(PROJECT).dylib"

clean:
	rm -rf $(OUTDIR)
```

---

### 2. GitHub 自动化配置：`build.yml`
**文件名：`.github/workflows/build.yml`**
```yaml
name: Build
on: [push, workflow_dispatch]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: 编译项目
        run: make

      - name: 上传产物
        uses: actions/upload-artifact@v4
        with:
          name: ClassDumpDylib
          path: packages/ClassDumpDylib.dylib
```

---

### 3. Hook 引擎头文件：`MethodHacker.h`
**文件名：`MethodHacker.h`**
```objectivec
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface ActiveHook : NSObject
@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *methodName;
@property (nonatomic, assign) BOOL isClassMethod;
@property (nonatomic, copy) NSString *returnType;
@property (nonatomic, strong) id returnValue;
@property (nonatomic, assign) IMP originalIMP;
@end

@interface MethodHacker : NSObject
+ (BOOL)hookMethodWithClass:(NSString *)className methodName:(NSString *)methodName isClassMethod:(BOOL)isClassMethod returnType:(NSString *)returnType value:(id)value;
+ (NSArray<ActiveHook *> *)activeHooks;
@end
```

---

### 4. Hook 引擎实现：`MethodHacker.m`
**文件名：`MethodHacker.m`**
```objectivec
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "MethodHacker.h"

@implementation ActiveHook
+ (instancetype)hookWithClass:(NSString *)cls method:(NSString *)sel isClass:(BOOL)cm returnType:(NSString *)type value:(id)val {
    ActiveHook *h = [self new];
    h.className = cls; h.methodName = sel; h.isClassMethod = cm; h.returnType = type; h.returnValue = val;
    return h;
}
@end

@implementation MethodHacker
static NSMutableArray *_hooks;

+ (void)initialize {
    if (self == [MethodHacker class]) _hooks = [NSMutableArray array];
}

+ (NSArray *)activeHooks { return [_hooks copy]; }

+ (BOOL)hookMethodWithClass:(NSString *)className methodName:(NSString *)methodName isClassMethod:(BOOL)isClassMethod returnType:(NSString *)returnType value:(id)value {
    Class cls = NSClassFromString(className);
    if (!cls) return NO;
    Class target = isClassMethod ? object_getClass(cls) : cls;
    SEL sel = NSSelectorFromString(methodName);
    Method method = class_getInstanceMethod(target, sel);
    if (!method) return NO;

    // 核心：使用 Block 替换实现
    IMP newImp = imp_implementationWithBlock(^(id _self) {
        NSLog(@"[Hacker] 命中 Hook: %@.%@", className, methodName);
        return value; 
    });

    method_setImplementation(method, newImp);
    
    ActiveHook *h = [ActiveHook hookWithClass:className method:methodName isClass:isClassMethod returnType:returnType value:value];
    [_hooks addObject:h];
    
    // 通知 UI 刷新列表
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"HookListReload" object:nil];
    });
    return YES;
}
@end
```

---

### 5. UI 窗口头文件：`SearchOverlayWindow.h`
**文件名：`SearchOverlayWindow.h`**
```objectivec
#import <UIKit/UIKit.h>

@interface SearchOverlayWindow : UIWindow
+ (instancetype)sharedInstance;
- (void)showTip:(NSString *)title msg:(NSString *)msg;
@end
```

---

### 6. UI 窗口实现：`SearchOverlayWindow.m`
**文件名：`SearchOverlayWindow.m`**
```objectivec
#import <UIKit/UIKit.h>
#import "SearchOverlayWindow.h"
#import "MethodHacker.h"

@implementation SearchOverlayWindow

+ (instancetype)sharedInstance {
    static SearchOverlayWindow *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithFrame:[UIScreen mainScreen].bounds];
        // 关键修复：降低层级，让 UIAlertController 能弹出来
        instance.windowLevel = UIWindowLevelStatusBar - 2;
        instance.rootViewController = [UIViewController new];
        instance.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
        instance.hidden = YES;
    });
    return instance;
}

// 通用弹窗反馈
- (void)showTip:(NSString *)title msg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [self makeKeyAndVisible]; // 激活当前窗口
        [self.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}

// 示例：点击 VIP 解锁按钮调用的方法
- (void)onVipButtonClicked {
    // 请在此填入你搜索到的实际类名和方法名
    BOOL ok = [MethodHacker hookMethodWithClass:@"UserCenter" methodName:@"isVip" isClassMethod:NO returnType:@"BOOL" value:@YES];
    [self showTip:ok?@"Hook 成功":@"Hook 失败" msg:@"请检查类名是否正确"];
}

// 示例：添加自定义 Hook
- (void)onAddCustomHook {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"自定义注入" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *t) { t.placeholder = @"类名 (如: AdManager)"; }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *t) { t.placeholder = @"方法名 (如: shouldShowAd)"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"注入" style:UIAlertActionStyleDestructive handler:^(id action) {
        NSString *cls = alert.textFields[0].text;
        NSString *sel = alert.textFields[1].text;
        BOOL ok = [MethodHacker hookMethodWithClass:cls methodName:sel isClassMethod:NO returnType:@"BOOL" value:@NO];
        [self showTip:ok?@"注入成功":@"类名/方法名不匹配" msg:nil];
    }]];
    [self makeKeyAndVisible];
    [self.rootViewController presentViewController:alert animated:YES completion:nil];
}

@end
```

---

### 7. 插件入口：`ClassDumpEntry.m`
**文件名：`ClassDumpEntry.m`**
```objectivec
#import <UIKit/UIKit.h>
#import "SearchOverlayWindow.h"

static void __attribute__((constructor)) initialize() {
    // 延迟加载，防止 App 启动时由于 UIWindow 还没初始化导致的崩溃
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SearchOverlayWindow *win = [SearchOverlayWindow sharedInstance];
        win.hidden = NO;
        
        // 关键逻辑：在系统的主窗口上加一个“三指点击”手势，用于万一界面被关了能叫回来
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:win action:@selector(makeKeyAndVisible)];
        tap.numberOfTouchesRequired = 3;
        [[UIApplication sharedApplication].keyWindow addGestureRecognizer:tap];
        
        NSLog(@"[Hacker] 插件已注入。三指点击屏幕可激活界面。");
    });
}
