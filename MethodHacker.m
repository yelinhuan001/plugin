#import "MethodHacker.h"

#pragma mark - ActiveHook

@implementation ActiveHook
+ (instancetype)hookWithClass:(NSString *)cls method:(NSString *)sel isClass:(BOOL)classMeth returnType:(NSString *)type value:(id)value {
    ActiveHook *h = [self new];
    h.className = cls;
    h.methodName = sel;
    h.isClassMethod = classMeth;
    h.returnType = type;
    h.returnValue = value;
    h.originalIMP = NULL;
    return h;
}
- (NSString *)displayDescription {
    return [NSString stringWithFormat:@"[%@] %@ → %@", self.className, self.methodName, self.returnValue ?: @"nil"];
}
@end

#pragma mark - MethodHacker

@implementation MethodHacker

static NSMutableArray<ActiveHook *> *_hooks = nil;
static NSMutableDictionary *_impBlocks = nil;  // 保存 block 防止被释放

+ (void)initialize {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        _hooks = [NSMutableArray array];
        _impBlocks = [NSMutableDictionary dictionary];
    });
}

+ (NSArray<ActiveHook *> *)activeHooks {
    return [_hooks copy];
}

#pragma mark - 核心 Hook 逻辑

+ (BOOL)hookMethodWithClass:(NSString *)className
                 methodName:(NSString *)methodName
              isClassMethod:(BOOL)isClassMethod
                 returnType:(NSString *)returnType
                      value:(id)value {

    if (!className || !methodName) return NO;

    // 获取类对象
    Class cls = NSClassFromString(className);
    if (!cls) return NO;

    // 如果是类方法，使用元类
    Class targetClass = isClassMethod ? objc_getMetaClass([className UTF8String]) : cls;
    if (!targetClass) return NO;

    // 获取方法的 SEL
    SEL sel = NSSelectorFromString(methodName);
    if (!sel) return NO;

    // 获取方法
    Method method = class_getInstanceMethod(targetClass, sel);
    if (!method) {
        NSLog(@"[Hacker] 方法 %@ 不存在于 %@", methodName, className);
        return NO;
    }

    // 保存原始 IMP
    IMP originalIMP = method_getImplementation(method);

    // 创建新的 IMP block
    id impBlock = [self createImpBlockForReturnType:returnType value:value method:method];
    if (!impBlock) return NO;

    IMP newIMP = imp_implementationWithBlock(impBlock);
    if (!newIMP) return NO;

    // 替换实现
    method_setImplementation(method, newIMP);

    // 记录 Hook
    ActiveHook *hook = [ActiveHook hookWithClass:className method:methodName isClass:isClassMethod returnType:returnType value:value];
    hook.originalIMP = originalIMP;
    [_hooks addObject:hook];

    // 保存 block 和 IMP 防止被释放
    NSString *key = [NSString stringWithFormat:@"%@-%@-%d", className, methodName, isClassMethod];
    _impBlocks[key] = impBlock;

    NSLog(@"[Hacker] ✅ Hook: %@ %@ → %@", className, methodName, value);
    return YES;
}

#pragma mark - 创建 IMP Block

+ (id)createImpBlockForReturnType:(NSString *)returnType value:(id)value method:(Method)method {
    // 获取参数数量（包括 self, _cmd）
    unsigned int argCount = method_getNumberOfArguments(method);

    // 根据返回类型创建对应的 block
    if ([returnType isEqualToString:@"BOOL"] || [returnType isEqualToString:@"bool"]) {
        BOOL retVal = [value boolValue];
        if (argCount <= 2) {
            return ^BOOL(id s, SEL c) { return retVal; };
        } else if (argCount <= 3) {
            return ^BOOL(id s, SEL c, id a1) { return retVal; };
        } else if (argCount <= 4) {
            return ^BOOL(id s, SEL c, id a1, id a2) { return retVal; };
        }
    }
    else if ([returnType isEqualToString:@"id"] || [returnType isEqualToString:@"object"]) {
        id retVal = value;
        if (argCount <= 2) {
            return ^id(id s, SEL c) { return retVal; };
        } else if (argCount <= 3) {
            return ^id(id s, SEL c, id a1) { return retVal; };
        } else if (argCount <= 4) {
            return ^id(id s, SEL c, id a1, id a2) { return retVal; };
        }
    }
    else if ([returnType isEqualToString:@"int"] || [returnType isEqualToString:@"NSInteger"]) {
        NSInteger retVal = [value integerValue];
        if (argCount <= 2) {
            return ^NSInteger(id s, SEL c) { return retVal; };
        } else if (argCount <= 3) {
            return ^NSInteger(id s, SEL c, id a1) { return retVal; };
        } else if (argCount <= 4) {
            return ^NSInteger(id s, SEL c, id a1, id a2) { return retVal; };
        }
    }
    else if ([returnType isEqualToString:@"double"] || [returnType isEqualToString:@"CGFloat"]) {
        double retVal = [value doubleValue];
        if (argCount <= 2) {
            return ^double(id s, SEL c) { return retVal; };
        } else if (argCount <= 3) {
            return ^double(id s, SEL c, id a1) { return retVal; };
        } else if (argCount <= 4) {
            return ^double(id s, SEL c, id a1, id a2) { return retVal; };
        }
    }
    else if ([returnType isEqualToString:@"void"]) {
        if (argCount <= 2) {
            return ^(id s, SEL c) { /* do nothing */ };
        } else if (argCount <= 3) {
            return ^(id s, SEL c, id a1) { /* do nothing */ };
        } else if (argCount <= 4) {
            return ^(id s, SEL c, id a1, id a2) { /* do nothing */ };
        }
    }
    else if ([returnType isEqualToString:@"char*"] || [returnType isEqualToString:@"string"]) {
        const char *retVal = [value UTF8String];
        if (argCount <= 2) {
            return ^const char *(id s, SEL c) { return retVal; };
        } else if (argCount <= 3) {
            return ^const char *(id s, SEL c, id a1) { return retVal; };
        }
    }

    // 默认返回 id 类型
    if (argCount <= 2) {
        return ^id(id s, SEL c) { return value; };
    } else if (argCount <= 3) {
        return ^id(id s, SEL c, id a1) { return value; };
    } else {
        return ^id(id s, SEL c, id a1, id a2) { return value; };
    }
}

#pragma mark - 取消 Hook

+ (BOOL)unhook:(ActiveHook *)hook {
    if (!hook) return NO;

    Class cls = NSClassFromString(hook.className);
    if (!cls) return NO;

    Class targetClass = hook.isClassMethod ? objc_getMetaClass([hook.className UTF8String]) : cls;
    SEL sel = NSSelectorFromString(hook.methodName);
    Method method = class_getInstanceMethod(targetClass, sel);

    if (method && hook.originalIMP) {
        method_setImplementation(method, hook.originalIMP);
        [_hooks removeObject:hook];

        NSString *key = [NSString stringWithFormat:@"%@-%@-%d", hook.className, hook.methodName, hook.isClassMethod];
        [_impBlocks removeObjectForKey:key];

        NSLog(@"[Hacker] 🔄 取消 Hook: %@", [hook displayDescription]);
        return YES;
    }
    return NO;
}

+ (void)unhookAll {
    for (ActiveHook *hook in [_hooks copy]) {
        [self unhook:hook];
    }
}

#pragma mark - 列出类

+ (NSArray<NSString *> *)allClassesFiltered:(NSString *)filter {
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses <= 0) return @[];

    Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classes, numClasses);

    NSMutableArray *result = [NSMutableArray array];
    NSString *lowerFilter = [filter lowercaseString];

    for (int i = 0; i < numClasses; i++) {
        NSString *name = NSStringFromClass(classes[i]);
        if (!name) continue;
        if (filter.length == 0 || [[name lowercaseString] containsString:lowerFilter]) {
            [result addObject:name];
        }
    }

    free(classes);
    [result sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return result;
}

@end
