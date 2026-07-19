#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "MethodHacker.h"

@implementation ActiveHook

+ (instancetype)hookWithClass:(NSString *)cls method:(NSString *)sel isClass:(BOOL)cm returnType:(NSString *)type value:(id)val {
    ActiveHook *h = [self new];
    h.className = cls;
    h.methodName = sel;
    h.isClassMethod = cm;
    h.returnType = type;
    h.returnValue = val;
    h.originalIMP = NULL;
    return h;
}

@end

#pragma mark -

@implementation MethodHacker

static NSMutableArray<ActiveHook *> *_hooks;
static NSMutableDictionary *_originalIMPs; // className.methodName -> IMP

+ (void)initialize {
    if (self == [MethodHacker class]) {
        _hooks = [NSMutableArray array];
        _originalIMPs = [NSMutableDictionary dictionary];
    }
}

+ (NSArray<ActiveHook *> *)activeHooks {
    return [_hooks copy];
}

+ (BOOL)hookMethodWithClass:(NSString *)className
                 methodName:(NSString *)methodName
              isClassMethod:(BOOL)isClassMethod
                 returnType:(NSString *)returnType
                      value:(id)value
{
    Class cls = NSClassFromString(className);
    if (!cls) return NO;

    Class target = isClassMethod ? object_getClass(cls) : cls;
    SEL sel = NSSelectorFromString(methodName);
    Method method = class_getInstanceMethod(target, sel);
    if (!method) return NO;

    // 保存原始 IMP（用于 unhook）
    NSString *key = [NSString stringWithFormat:@"%@.%@", className, methodName];
    if (!_originalIMPs[key]) {
        _originalIMPs[key] = [NSValue valueWithPointer:method_getImplementation(method)];
    }

    // 获取方法类型编码
    const char *typeEncoding = method_getTypeEncoding(method);

    // 用 Block 替换实现
    IMP newImp = imp_implementationWithBlock(^(id _self) {
        NSLog(@"[Hacker] 命中 Hook: %@.%@", className, methodName);
        return value;
    });

    // 使用 class_replaceMethod 以正确处理父类方法
    IMP old = class_replaceMethod(target, sel, newImp, typeEncoding);
    if (!_originalIMPs[key] && old) {
        _originalIMPs[key] = [NSValue valueWithPointer:old];
    }

    // 检查是否已存在相同 hook
    for (ActiveHook *existing in _hooks) {
        if ([existing.className isEqualToString:className] &&
            [existing.methodName isEqualToString:methodName] &&
            existing.isClassMethod == isClassMethod) {
            existing.returnValue = value;
            existing.returnType = returnType;
            // 通知 UI 刷新
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"HookListReload" object:nil];
            });
            return YES;
        }
    }

    ActiveHook *h = [ActiveHook hookWithClass:className
                                       method:methodName
                                      isClass:isClassMethod
                                   returnType:returnType
                                        value:value];
    [_hooks addObject:h];

    // 通知 UI 刷新
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"HookListReload" object:nil];
    });
    return YES;
}

+ (BOOL)unhook:(ActiveHook *)hook {
    if (!hook) return NO;

    Class cls = NSClassFromString(hook.className);
    if (!cls) return NO;

    Class target = hook.isClassMethod ? object_getClass(cls) : cls;
    SEL sel = NSSelectorFromString(hook.methodName);
    Method method = class_getInstanceMethod(target, sel);
    if (!method) return NO;

    NSString *key = [NSString stringWithFormat:@"%@.%@", hook.className, hook.methodName];
    NSValue *originalIMPPtr = _originalIMPs[key];
    if (originalIMPPtr) {
        IMP originalIMP = [originalIMPPtr pointerValue];
        const char *typeEncoding = method_getTypeEncoding(method);
        class_replaceMethod(target, sel, originalIMP, typeEncoding);
        [_originalIMPs removeObjectForKey:key];
    }

    [_hooks removeObject:hook];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"HookListReload" object:nil];
    });
    return YES;
}

+ (void)unhookAll {
    for (ActiveHook *hook in [_hooks copy]) {
        [self unhook:hook];
    }
}

@end
