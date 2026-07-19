#import <UIKit/UIKit.h>
#import "MethodHacker.h"

NSString *const HookLogDidUpdateNotification = @"HookLogDidUpdateNotification";

#pragma mark - ActiveHook

@implementation ActiveHook
+ (instancetype)hookWithClass:(NSString *)cls method:(NSString *)sel isClass:(BOOL)cm {
    ActiveHook *h = [self new];
    h.className = cls;
    h.methodName = sel;
    h.isClassMethod = cm;
    h.hookType = HookTypeReturn;
    h.callCount = 0;
    return h;
}
@end

#pragma mark - MethodHacker

@implementation MethodHacker

static NSMutableArray<ActiveHook *> *_hooks;
static NSMutableDictionary *_originalIMPs;
static NSMutableArray<NSString *> *_hookLogs;
static NSMutableDictionary *_logIMPs; // 存储 Log Hook 的 IMP，以便取消

+ (void)initialize {
    if (self == [MethodHacker class]) {
        _hooks = [NSMutableArray array];
        _originalIMPs = [NSMutableDictionary dictionary];
        _hookLogs = [NSMutableArray array];
        _logIMPs = [NSMutableDictionary dictionary];
    }
}

+ (NSArray<ActiveHook *> *)activeHooks { return [_hooks copy]; }
+ (NSArray<NSString *> *)hookLogs { return [_hookLogs copy]; }
+ (void)clearLogs { @synchronized(_hookLogs) { [_hookLogs removeAllObjects]; } }

#pragma mark - 通用 Hook 方法

+ (BOOL)hookMethodWithClass:(NSString *)className
                 methodName:(NSString *)methodName
              isClassMethod:(BOOL)isClassMethod
                 returnType:(NSString *)returnType
                      value:(id)value
{
    return [self hookMethodWithClass:className
                          methodName:methodName
                       isClassMethod:isClassMethod
                            hookType:HookTypeReturn
                          returnType:returnType
                               value:value];
}

+ (BOOL)hookMethodWithClass:(NSString *)className
                 methodName:(NSString *)methodName
              isClassMethod:(BOOL)isClassMethod
                   hookType:(HookType)type
                 returnType:(NSString *)returnType
                      value:(id)value
{
    Class cls = NSClassFromString(className);
    if (!cls) return NO;

    Class target = isClassMethod ? object_getClass(cls) : cls;
    SEL sel = NSSelectorFromString(methodName);
    Method method = class_getInstanceMethod(target, sel);
    if (!method) return NO;

    const char *typeEncoding = method_getTypeEncoding(method);
    NSString *key = [NSString stringWithFormat:@"%@.%@.%d", className, methodName, isClassMethod];

    // 保存原始 IMP
    IMP originalIMP = method_getImplementation(method);
    if (!_originalIMPs[key]) {
        _originalIMPs[key] = [NSValue valueWithPointer:originalIMP];
    }

    IMP newImp = NULL;

    switch (type) {
        case HookTypeReturn: {
            // 返回固定值 - 使用 Block
            id returnVal = value;
            newImp = imp_implementationWithBlock(^(id _self) {
                return returnVal;
            });
            break;
        }
        case HookTypeLog: {
            // 日志模式 - 记录调用后转发给原始实现
            __block IMP orig = originalIMP;
            NSString *clsName = [className copy];
            NSString *selName = [methodName copy];
            newImp = imp_implementationWithBlock(^(id _self) {
                // 记录日志
                NSString *log = [NSString stringWithFormat:@"[HookLog] %@.%@ 被调用", clsName, selName];
                @synchronized(_hookLogs) {
                    [_hookLogs addObject:log];
                    if (_hookLogs.count > 500) {
                        [_hookLogs removeObjectsInRange:NSMakeRange(0, _hookLogs.count - 500)];
                    }
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:HookLogDidUpdateNotification object:log];
                });

                // 更新调用计数
                for (ActiveHook *h in _hooks) {
                    if ([h.className isEqualToString:clsName] && [h.methodName isEqualToString:selName]) {
                        h.callCount++;
                        break;
                    }
                }

                // 调用原始实现
                if (orig) {
                    return ((id (*)(id, SEL, ...))orig)(_self, sel);
                }
                return (id)nil;
            });
            _logIMPs[key] = [NSValue valueWithPointer:newImp];
            break;
        }
        case HookTypeBlock: {
            // 自定义 Block - 使用传入的 value 作为 block
            if ([value isKindOfClass:NSClassFromString(@"NSBlock")]) {
                newImp = imp_implementationWithBlock(value);
            } else {
                return NO;
            }
            break;
        }
        case HookTypeSwizzle: {
            // Method Swizzle - 与原实现交换
            // 创建一个带日志的交换实现
            __block IMP orig = originalIMP;
            NSString *clsName = [className copy];
            NSString *selName = [methodName copy];
            newImp = imp_implementationWithBlock(^(id _self) {
                NSLog(@"[Swizzle] %@.%@ 被调用", clsName, selName);
                if (orig) {
                    return ((id (*)(id, SEL, ...))orig)(_self, sel);
                }
                return (id)nil;
            });
            break;
        }
        case HookTypeKVC: {
            // KVC 模式 - 通过 setValue:forKeyPath: 修改属性
            // 这不是方法 Hook，用单独的入口
            return NO;
        }
    }

    if (newImp) {
        class_replaceMethod(target, sel, newImp, typeEncoding);
    }

    // 检查是否已存在
    for (ActiveHook *existing in _hooks) {
        if ([existing.className isEqualToString:className] &&
            [existing.methodName isEqualToString:methodName] &&
            existing.isClassMethod == isClassMethod) {
            existing.hookType = type;
            existing.returnValue = value;
            existing.returnType = returnType;
            [self notifyReload];
            return YES;
        }
    }

    ActiveHook *h = [ActiveHook hookWithClass:className method:methodName isClass:isClassMethod];
    h.hookType = type;
    h.returnValue = value;
    h.returnType = returnType;
    h.originalIMP = originalIMP;
    [_hooks addObject:h];

    [self notifyReload];
    return YES;
}

#pragma mark - Log Hook

+ (BOOL)addLogHookForClass:(NSString *)className
                methodName:(NSString *)methodName
             isClassMethod:(BOOL)isClassMethod
{
    return [self hookMethodWithClass:className
                          methodName:methodName
                       isClassMethod:isClassMethod
                            hookType:HookTypeLog
                          returnType:@"void"
                               value:nil];
}

#pragma mark - KVC 属性修改

+ (BOOL)modifyPropertyWithClass:(NSString *)className
                       keyPath:(NSString *)keyPath
                         value:(id)value
{
    Class cls = NSClassFromString(className);
    if (!cls || keyPath.length == 0) return NO;

    @try {
        // 尝试通过 sharedInstance/shared 获取实例
        id target = nil;
        SEL sharedSel = NSSelectorFromString(@"sharedInstance");
        if ([cls respondsToSelector:sharedSel]) {
            target = [cls performSelector:sharedSel];
        } else {
            sharedSel = NSSelectorFromString(@"shared");
            if ([cls respondsToSelector:sharedSel]) {
                target = [cls performSelector:sharedSel];
            }
        }

        if (target) {
            [target setValue:value forKeyPath:keyPath];

            ActiveHook *h = [ActiveHook hookWithClass:className method:keyPath isClass:NO];
            h.hookType = HookTypeKVC;
            h.kvcKeyPath = keyPath;
            h.kvcValue = value;
            [_hooks addObject:h];

            [self notifyReload];
            return YES;
        }
    } @catch (NSException *e) {
        NSLog(@"[Hacker] KVC 失败: %@", e.reason);
    }
    return NO;
}

#pragma mark - Unhook

+ (BOOL)unhook:(ActiveHook *)hook {
    if (!hook) return NO;

    Class cls = NSClassFromString(hook.className);
    if (!cls) return NO;

    Class target = hook.isClassMethod ? object_getClass(cls) : cls;
    SEL sel = NSSelectorFromString(hook.methodName);
    Method method = class_getInstanceMethod(target, sel);
    if (!method) return NO;

    NSString *key = [NSString stringWithFormat:@"%@.%@.%d", hook.className, hook.methodName, hook.isClassMethod];

    // 恢复原始 IMP
    NSValue *originalIMPPtr = _originalIMPs[key];
    if (originalIMPPtr) {
        IMP originalIMP = [originalIMPPtr pointerValue];
        const char *typeEncoding = method_getTypeEncoding(method);
        class_replaceMethod(target, sel, originalIMP, typeEncoding);
    }

    // 清理 Log IMP
    NSValue *logIMPPtr = _logIMPs[key];
    if (logIMPPtr) {
        IMP logIMP = [logIMPPtr pointerValue];
        imp_removeBlock(logIMP);
        [_logIMPs removeObjectForKey:key];
    }

    [_originalIMPs removeObjectForKey:key];
    [_hooks removeObject:hook];

    [self notifyReload];
    return YES;
}

+ (void)unhookAll {
    for (ActiveHook *hook in [_hooks copy]) {
        [self unhook:hook];
    }
}

#pragma mark - 通知

+ (void)notifyReload {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"HookListReload" object:nil];
    });
}

@end
