# 常用 Hook 写法示例

把片段粘贴进 `TweakStandalone.m` 的 `TDP_CustomLogic` 或单独函数中。

## 1. 改 BOOL 返回值

```objc
static IMP orig_isPremium = NULL;
static BOOL hook_isPremium(id self, SEL _cmd) {
    return YES;
}

Class c = NSClassFromString(@"MembershipManager");
TDP_SwizzleInstanceMethod(c, NSSelectorFromString(@"isPremium"),
                          (IMP)hook_isPremium, &orig_isPremium);
```

## 2. 先调用原实现再改结果

```objc
static IMP orig_getScore = NULL;
static NSInteger hook_getScore(id self, SEL _cmd) {
    NSInteger v = ((NSInteger (*)(id, SEL))orig_getScore)(self, _cmd);
    return v + 100;
}
```

## 3. Hook 带参数方法

```objc
static IMP orig_request = NULL;
static void hook_request(id self, SEL _cmd, NSString *url, id callback) {
    NSLog(@"request url = %@", url);
    ((void (*)(id, SEL, NSString *, id))orig_request)(self, _cmd, url, callback);
}
```

## 4. 替换 Block 前注意

Block 的类型编码和调用约定复杂，优先 Hook 外层 ObjC 方法，而不是直接改 Block 内存。

## 5. 找类名 / 方法名

- `class-dump` 目标二进制  
- Frida: `ObjC.enumerateLoadedClasses()`  
- 越狱: Cycript / flex  

## 6. 注入后不生效排查

1. Bundle ID 是否被 `kTargetBundleID` 过滤  
2. 类是否在 dylib 加载时已存在（可延迟 `dispatch_after` 再 Hook）  
3. 方法是否在分类 / 父类（Swizzle 当前类即可）  
4. 是否 Swift 方法（需 mangled name 或 `@objc` 名）  
