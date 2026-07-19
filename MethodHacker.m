### 1. `Makefile` (项目配置文件)
**路径：根目录/Makefile**
```makefile
PROJECT = ClassDumpDylib
OUTDIR  = packages
FILES   = ClassDumpEntry.m ClassDumpSearcher.m SearchOverlayWindow.m MethodHacker.m UserDefaultsEditor.m

# 编译参数：包含常用框架，解决 CACurrentMediaTime 报错
CFLAGS  = -fobjc-arc -I. -O2
LDFLAGS = -dynamiclib -lobjc \
          -framework UIKit \
          -framework Foundation \
          -framework QuartzCore \
          -framework CoreGraphics

ARCHS   = -arch arm64 -arch arm64e

SDK_PATH ?= $(shell xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)

all: $(OUTDIR)/$(PROJECT).dylib

$(OUTDIR)/$(PROJECT).dylib: $(FILES)
	@mkdir -p $(OUTDIR)
	@echo "——> 正在编译..."
	clang $(ARCHS) $(CFLAGS) \
		-isysroot "$(SDK_PATH)" \
		-miphoneos-version-min=14.0 \
		$(LDFLAGS) \
		$(FILES) \
		-o $(OUTDIR)/$(PROJECT).dylib
	@echo " 编译完成: $(OUTDIR)/$(PROJECT).dylib"

clean:
	rm -rf $(OUTDIR)
```

### 2. `build.yml` (GitHub Actions 配置)
**路径：.github/workflows/build.yml**
```yaml
name: Build
on: [push, workflow_dispatch]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: 编译
        run: make

      - name: 上传产物
        uses: actions/upload-artifact@v4
        with:
          name: ClassDumpDylib
          path: packages/ClassDumpDylib.dylib
```

### 3. `MethodHacker.h` (Hook引擎头文件)
**路径：MethodHacker.h**
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
+ (void)unhookAll;
@end
```

### 4. `MethodHacker.m` (Hook引擎实现 - 增加反馈逻辑)
**路径：MethodHacker.m**
```objectivec
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

    IMP newImp = imp_implementationWithBlock(^(id _self) {
        NSLog(@"[Hacker] 命中 Hook: %@.%@", className, methodName);
        return value; 
    });

    method_setImplementation(method, newImp);
    
    ActiveHook *h = [ActiveHook hookWithClass:className method:methodName isClass:isClassMethod returnType:returnType value:value];
    [_hooks addObject:h];
    
    // 发送刷新通知
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"HookListReload" object:nil];
    });
    return YES;
}

+ (void)unhookAll { [_hooks removeAllObjects]; }
@end
```

### 5. `SearchOverlayWindow.m` (UI界面 - 核心修复层级与点击)
**路径：SearchOverlayWindow.m**
```objectivec
#import "SearchOverlayWindow.h"
#import "MethodHacker.h"

@implementation SearchOverlayWindow

+ (instancetype)sharedInstance {
    static SearchOverlayWindow *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithFrame:[UIScreen mainScreen].bounds];
        // 关键修复：降低层级，让 Alert 能显示出来
        instance.windowLevel = UIWindowLevelStatusBar - 2;
        instance.rootViewController = [UIViewController new];
        instance.hidden = YES;
    });
    return instance;
}

// 统一弹窗方法
- (void)showTip:(NSString *)title msg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [self makeKeyAndVisible]; // 确保窗口活跃
        [self.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}

// 示例：点击 VIP 解锁按钮
- (void)btnVipClicked {
    // 这里填入你搜索到的实际类名和方法名
    BOOL ok = [MethodHacker hookMethodWithClass:@"UserCenter" methodName:@"isVip" isClassMethod:NO returnType:@"BOOL" value:@YES];
    [self showTip:ok?@"成功":@"失败" msg:@"VIP权限已尝试注入"];
}

// 示例：点击 自定义 Hook 按钮
- (void)btnCustomHook {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"自定义注入" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *t) { t.placeholder = @"类名"; }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *t) { t.placeholder = @"方法名"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"注入" style:UIAlertActionStyleDefault handler:^(id action) {
        NSString *c = alert.textFields[0].text;
        NSString *m = alert.textFields[1].text;
        BOOL ok = [MethodHacker hookMethodWithClass:c methodName:m isClassMethod:NO returnType:@"BOOL" value:@YES];
        [self showTip:ok?@"完成":@"类/方法不存在" msg:nil];
    }]];
    [self makeKeyAndVisible];
    [self.rootViewController presentViewController:alert animated:YES completion:nil];
}

@end
```

### 6. `ClassDumpEntry.m` (入口文件 - 增加唤出逻辑)
**路径：ClassDumpEntry.m**
```objectivec
#import "SearchOverlayWindow.h"

static void __attribute__((constructor)) initialize() {
    // 延迟3秒加载，避开App启动崩溃
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SearchOverlayWindow *win = [SearchOverlayWindow sharedInstance];
        win.hidden = NO;
        
        // 关键逻辑：给系统窗口加个手势，万一界面关了能点回来
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:win action:@selector(makeKeyAndVisible)];
        tap.numberOfTouchesRequired = 3; // 三指点击唤出
        [[UIApplication sharedApplication].keyWindow addGestureRecognizer:tap];
        
        NSLog(@"[Hacker] 插件已就绪，三指点击屏幕可唤出界面");
    });
}
