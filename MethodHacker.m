#import "MethodHacker.h"
#import <objc/message.h>

#pragma mark - ActiveHook

@implementation ActiveHook
+ (instancetype)hookWithClass:(NSString *)cls method:(NSString *)sel isClass:(BOOL)classMeth returnType:(NSString *)type value:(id)value {
    ActiveHook *h = [self new];
    h.className = cls ?: @"";
    h.methodName = sel ?: @"";
    h.isClassMethod = classMeth;
    h.returnType = type ?: @"auto";
    h.returnValue = value;
    h.originalIMP = NULL;
    return h;
}
- (NSString *)displayDescription {
    return [NSString stringWithFormat:@"[%@] %@%@ → %@",
            self.className,
            self.isClassMethod ? @"+" : @"-",
            self.methodName,
            self.returnValue ?: @"nil"];
}
@end

#pragma mark - MethodHacker

@implementation MethodHacker

static NSMutableArray<ActiveHook *> *_hooks = nil;
static NSMutableDictionary *_impBlocks = nil;
static NSMutableDictionary *_impPtrs = nil; // key -> NSValue(IMP) for free later if needed

+ (void)initialize {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        _hooks = [NSMutableArray array];
        _impBlocks = [NSMutableDictionary dictionary];
        _impPtrs = [NSMutableDictionary dictionary];
    });
}

+ (NSArray<ActiveHook *> *)activeHooks {
    @synchronized (_hooks) {
        return [_hooks copy];
    }
}

+ (NSString *)hookKey:(NSString *)className method:(NSString *)method isClass:(BOOL)isClass {
    return [NSString stringWithFormat:@"%@|%@|%d", className, method, isClass ? 1 : 0];
}

#pragma mark - Type helpers

+ (NSString *)readableTypeFromEncoding:(const char *)enc {
    if (!enc || enc[0] == '\0') return @"id";
    // skip const / qualifiers
    while (*enc == 'r' || *enc == 'n' || *enc == 'N' || *enc == 'o' || *enc == 'O' ||
           *enc == 'R' || *enc == 'V') enc++;
    switch (enc[0]) {
        case 'v': return @"void";
        case 'B': return @"BOOL";
        case 'c': case 'C': return @"BOOL"; // often BOOL on older ABIs
        case 'i': case 's': case 'l': case 'q':
        case 'I': case 'S': case 'L': case 'Q': return @"NSInteger";
        case 'f': case 'd': return @"double";
        case '@': return @"id";
        case '*': return @"char*";
        case ':': return @"SEL";
        case '#': return @"Class";
        default: return @"id";
    }
}

+ (NSString *)readableReturnTypeForClass:(NSString *)className
                              methodName:(NSString *)methodName
                           isClassMethod:(BOOL)isClassMethod {
    Class cls = NSClassFromString(className);
    if (!cls) return @"id";
    Class target = isClassMethod ? object_getClass(cls) : cls;
    Method m = class_getInstanceMethod(target, NSSelectorFromString(methodName));
    if (!m) return @"id";
    char *ret = method_copyReturnType(m);
    NSString *r = [self readableTypeFromEncoding:ret];
    if (ret) free(ret);
    return r;
}

+ (id)coerceValue:(id)value forReturnType:(NSString *)returnType {
    if ([returnType isEqualToString:@"void"]) return nil;
    if ([returnType isEqualToString:@"BOOL"] || [returnType isEqualToString:@"bool"]) {
        if ([value isKindOfClass:[NSNumber class]]) return value;
        if ([value isKindOfClass:[NSString class]]) {
            NSString *s = [(NSString *)value lowercaseString];
            if ([s isEqualToString:@"yes"] || [s isEqualToString:@"true"] || [s isEqualToString:@"1"]) return @YES;
            if ([s isEqualToString:@"no"] || [s isEqualToString:@"false"] || [s isEqualToString:@"0"]) return @NO;
        }
        return value ? @YES : @NO;
    }
    if ([returnType isEqualToString:@"NSInteger"] || [returnType isEqualToString:@"int"]) {
        if ([value isKindOfClass:[NSNumber class]]) return value;
        if ([value isKindOfClass:[NSString class]]) return @([(NSString *)value integerValue]);
        return @(0);
    }
    if ([returnType isEqualToString:@"double"] || [returnType isEqualToString:@"CGFloat"]) {
        if ([value isKindOfClass:[NSNumber class]]) return value;
        if ([value isKindOfClass:[NSString class]]) return @([(NSString *)value doubleValue]);
        return @(0.0);
    }
    if ([returnType isEqualToString:@"id"] || [returnType isEqualToString:@"object"]) {
        if ([value isKindOfClass:[NSString class]] &&
            ([[(NSString *)value lowercaseString] isEqualToString:@"nil"] ||
             [[(NSString *)value lowercaseString] isEqualToString:@"(nil)"] ||
             [(NSString *)value length] == 0)) {
            return nil;
        }
        return value;
    }
    return value;
}

#pragma mark - Core Hook

+ (BOOL)hookMethodWithClass:(NSString *)className
                 methodName:(NSString *)methodName
              isClassMethod:(BOOL)isClassMethod
                 returnType:(NSString *)returnType
                      value:(id)value {

    if (className.length == 0 || methodName.length == 0) return NO;

    // 允许 "Class.method" 或 "-[Class method]" / "+[Class method]" 形式
    methodName = [methodName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([methodName hasPrefix:@"-["] || [methodName hasPrefix:@"+["]) {
        BOOL looksClass = [methodName hasPrefix:@"+["];
        NSRange r1 = [methodName rangeOfString:@" "];
        NSRange r2 = [methodName rangeOfString:@"]"];
        if (r1.location != NSNotFound && r2.location != NSNotFound && r2.location > r1.location) {
            methodName = [methodName substringWithRange:NSMakeRange(r1.location + 1, r2.location - r1.location - 1)];
            if (looksClass) isClassMethod = YES;
        }
    }

    Class cls = NSClassFromString(className);
    if (!cls) {
        NSLog(@"[Hacker] 类不存在: %@", className);
        return NO;
    }

    Class targetClass = isClassMethod ? object_getClass(cls) : cls;
    if (!targetClass) return NO;

    SEL sel = NSSelectorFromString(methodName);
    if (!sel) return NO;

    Method method = class_getInstanceMethod(targetClass, sel);
    if (!method) {
        // 父类方法：复制到本类再 Hook
        Method superM = class_getInstanceMethod(isClassMethod ? object_getClass(class_getSuperclass(cls)) : class_getSuperclass(cls), sel);
        if (superM) {
            const char *types = method_getTypeEncoding(superM);
            class_addMethod(targetClass, sel, method_getImplementation(superM), types);
            method = class_getInstanceMethod(targetClass, sel);
        }
    }
    if (!method) {
        NSLog(@"[Hacker] 方法不存在: %@ %@", className, methodName);
        return NO;
    }

    // 自动识别返回类型
    NSString *resolvedType = returnType;
    if (resolvedType.length == 0 ||
        [resolvedType.lowercaseString isEqualToString:@"auto"] ||
        [resolvedType.lowercaseString isEqualToString:@"自动"]) {
        char *ret = method_copyReturnType(method);
        resolvedType = [self readableTypeFromEncoding:ret];
        if (ret) free(ret);
    }

    id coerced = [self coerceValue:value forReturnType:resolvedType];

    // 若已 Hook 过同一方法，先还原
    NSString *key = [self hookKey:className method:methodName isClass:isClassMethod];
    @synchronized (_hooks) {
        for (ActiveHook *existing in [_hooks copy]) {
            NSString *ek = [self hookKey:existing.className method:existing.methodName isClass:existing.isClassMethod];
            if ([ek isEqualToString:key]) {
                [self unhook:existing];
                break;
            }
        }
    }

    IMP originalIMP = method_getImplementation(method);
    const char *encoding = method_getTypeEncoding(method);

    id impBlock = [self createImpBlockForReturnType:resolvedType value:coerced method:method];
    if (!impBlock) {
        NSLog(@"[Hacker] 无法创建 IMP block: %@ %@", className, methodName);
        return NO;
    }

    IMP newIMP = imp_implementationWithBlock(impBlock);
    if (!newIMP) return NO;

    // 优先 add（父类方法场景），否则 set
    if (!class_addMethod(targetClass, sel, newIMP, encoding)) {
        method_setImplementation(method, newIMP);
    }

    ActiveHook *hook = [ActiveHook hookWithClass:className method:methodName isClass:isClassMethod returnType:resolvedType value:coerced];
    hook.originalIMP = originalIMP;
    hook.typeEncoding = encoding ? [NSString stringWithUTF8String:encoding] : nil;

    @synchronized (_hooks) {
        [_hooks addObject:hook];
        _impBlocks[key] = impBlock;
        _impPtrs[key] = [NSValue valueWithPointer:newIMP];
    }

    NSLog(@"[Hacker] ✅ Hook %@[%@ %@] → %@ (%@)",
          isClassMethod ? @"+" : @"-", className, methodName, coerced ?: @"nil", resolvedType);
    return YES;
}

+ (BOOL)hookPropertyWithClass:(NSString *)className propertyName:(NSString *)propertyName value:(id)value {
    if (className.length == 0 || propertyName.length == 0) return NO;
    Class cls = NSClassFromString(className);
    if (!cls) return NO;

    NSString *getter = propertyName;
    objc_property_t prop = class_getProperty(cls, propertyName.UTF8String);
    if (prop) {
        const char *attrs = property_getAttributes(prop);
        // GcustomGetter
        if (attrs) {
            NSString *attrStr = [NSString stringWithUTF8String:attrs];
            for (NSString *part in [attrStr componentsSeparatedByString:@","]) {
                if ([part hasPrefix:@"G"] && part.length > 1) {
                    getter = [part substringFromIndex:1];
                    break;
                }
            }
        }
    }

    // 尝试 isXxx
    Method m = class_getInstanceMethod(cls, NSSelectorFromString(getter));
    if (!m && propertyName.length > 0) {
        NSString *isName = [NSString stringWithFormat:@"is%@%@",
                            [[propertyName substringToIndex:1] uppercaseString],
                            [propertyName substringFromIndex:1]];
        if (class_getInstanceMethod(cls, NSSelectorFromString(isName))) {
            getter = isName;
        }
    }

    return [self hookMethodWithClass:className methodName:getter isClassMethod:NO returnType:@"auto" value:value];
}

#pragma mark - IMP Blocks

+ (id)createImpBlockForReturnType:(NSString *)returnType value:(id)value method:(Method)method {
    unsigned int argCount = method_getNumberOfArguments(method); // includes self, _cmd
    // 支持 self+_cmd + 最多 4 个额外参数（ObjC 常见）
    // 额外参数按 id 接收；对 BOOL/int 等小类型在 arm64 上也通常可安全忽略值

    if ([returnType isEqualToString:@"BOOL"] || [returnType isEqualToString:@"bool"]) {
        BOOL retVal = [value boolValue];
        switch (argCount) {
            case 0: case 1: case 2:
                return ^BOOL(id s, SEL c) { return retVal; };
            case 3:
                return ^BOOL(id s, SEL c, id a1) { return retVal; };
            case 4:
                return ^BOOL(id s, SEL c, id a1, id a2) { return retVal; };
            case 5:
                return ^BOOL(id s, SEL c, id a1, id a2, id a3) { return retVal; };
            default:
                return ^BOOL(id s, SEL c, id a1, id a2, id a3, id a4) { return retVal; };
        }
    }

    if ([returnType isEqualToString:@"NSInteger"] || [returnType isEqualToString:@"int"]) {
        NSInteger retVal = [value integerValue];
        switch (argCount) {
            case 0: case 1: case 2:
                return ^NSInteger(id s, SEL c) { return retVal; };
            case 3:
                return ^NSInteger(id s, SEL c, id a1) { return retVal; };
            case 4:
                return ^NSInteger(id s, SEL c, id a1, id a2) { return retVal; };
            case 5:
                return ^NSInteger(id s, SEL c, id a1, id a2, id a3) { return retVal; };
            default:
                return ^NSInteger(id s, SEL c, id a1, id a2, id a3, id a4) { return retVal; };
        }
    }

    if ([returnType isEqualToString:@"double"] || [returnType isEqualToString:@"CGFloat"]) {
        double retVal = [value doubleValue];
        switch (argCount) {
            case 0: case 1: case 2:
                return ^double(id s, SEL c) { return retVal; };
            case 3:
                return ^double(id s, SEL c, id a1) { return retVal; };
            case 4:
                return ^double(id s, SEL c, id a1, id a2) { return retVal; };
            default:
                return ^double(id s, SEL c, id a1, id a2, id a3) { return retVal; };
        }
    }

    if ([returnType isEqualToString:@"void"]) {
        switch (argCount) {
            case 0: case 1: case 2:
                return ^(id s, SEL c) {};
            case 3:
                return ^(id s, SEL c, id a1) {};
            case 4:
                return ^(id s, SEL c, id a1, id a2) {};
            default:
                return ^(id s, SEL c, id a1, id a2, id a3) {};
        }
    }

    // id / default
    id retVal = value;
    switch (argCount) {
        case 0: case 1: case 2:
            return ^id(id s, SEL c) { return retVal; };
        case 3:
            return ^id(id s, SEL c, id a1) { return retVal; };
        case 4:
            return ^id(id s, SEL c, id a1, id a2) { return retVal; };
        case 5:
            return ^id(id s, SEL c, id a1, id a2, id a3) { return retVal; };
        default:
            return ^id(id s, SEL c, id a1, id a2, id a3, id a4) { return retVal; };
    }
}

#pragma mark - Unhook

+ (BOOL)unhook:(ActiveHook *)hook {
    if (!hook) return NO;

    Class cls = NSClassFromString(hook.className);
    if (!cls) return NO;

    Class targetClass = hook.isClassMethod ? object_getClass(cls) : cls;
    SEL sel = NSSelectorFromString(hook.methodName);
    Method method = class_getInstanceMethod(targetClass, sel);

    if (method && hook.originalIMP) {
        method_setImplementation(method, hook.originalIMP);

        NSString *key = [self hookKey:hook.className method:hook.methodName isClass:hook.isClassMethod];
        @synchronized (_hooks) {
            [_hooks removeObject:hook];
            id block = _impBlocks[key];
            NSValue *impVal = _impPtrs[key];
            if (impVal) {
                IMP imp = impVal.pointerValue;
                if (imp) imp_removeBlock(imp);
            }
            [_impBlocks removeObjectForKey:key];
            [_impPtrs removeObjectForKey:key];
            (void)block;
        }

        NSLog(@"[Hacker] 🔄 取消 Hook: %@", [hook displayDescription]);
        return YES;
    }
    return NO;
}

+ (void)unhookAll {
    for (ActiveHook *hook in [self activeHooks]) {
        [self unhook:hook];
    }
}

#pragma mark - Listing

+ (BOOL)shouldSkipClassName:(NSString *)name {
    if (name.length == 0) return YES;
    static NSArray *prefixes = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        prefixes = @[
            @"NS", @"UI", @"CA", @"CF", @"CG", @"CI", @"CL", @"CM", @"CN", @"CT",
            @"AV", @"MK", @"MT", @"SK", @"WK", @"XC", @"__", @"OS_", @"_",
            @"Swift", @"_Tt", @"JS", @"Web", @"PF", @"BSX", @"AFN",
            @"SearchOverlay", @"ClassDump", @"MethodHacker", @"UserDefaultsEditor"
        ];
    });
    for (NSString *p in prefixes) {
        if ([name hasPrefix:p]) return YES;
    }
    return NO;
}

+ (NSArray<NSString *> *)allClassesFiltered:(NSString *)filter {
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses <= 0) return @[];

    Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * (size_t)numClasses);
    numClasses = objc_getClassList(classes, numClasses);

    NSMutableArray *result = [NSMutableArray array];
    NSString *lowerFilter = filter.lowercaseString;

    for (int i = 0; i < numClasses; i++) {
        NSString *name = NSStringFromClass(classes[i]);
        if (!name || [self shouldSkipClassName:name]) continue;
        if (filter.length == 0 || [name.lowercaseString containsString:lowerFilter]) {
            [result addObject:name];
        }
    }

    free(classes);
    [result sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return result;
}

+ (NSArray<NSString *> *)methodsOfClass:(NSString *)className
                          isClassMethod:(BOOL)isClassMethod
                                 filter:(NSString *)filter {
    Class cls = NSClassFromString(className);
    if (!cls) return @[];
    Class target = isClassMethod ? object_getClass(cls) : cls;
    unsigned int count = 0;
    Method *methods = class_copyMethodList(target, &count);
    NSMutableArray *arr = [NSMutableArray array];
    NSString *lf = filter.lowercaseString;
    for (unsigned int i = 0; i < count; i++) {
        NSString *n = NSStringFromSelector(method_getName(methods[i]));
        if (!n) continue;
        if (filter.length == 0 || [n.lowercaseString containsString:lf]) {
            [arr addObject:n];
        }
    }
    free(methods);
    [arr sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return arr;
}

+ (NSString *)exportHooksAsCode {
    NSArray *hooks = [self activeHooks];
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"// Auto-generated by ClassDumpDylib\n"];
    [s appendFormat:@"// Bundle: %@\n", [[NSBundle mainBundle] bundleIdentifier] ?: @"?"];
    [s appendFormat:@"// Hooks: %lu\n\n", (unsigned long)hooks.count];

    for (ActiveHook *h in hooks) {
        NSString *prefix = h.isClassMethod ? @"+" : @"-";
        [s appendFormat:@"// %@[%@ %@] → %@ (%@)\n", prefix, h.className, h.methodName, h.returnValue ?: @"nil", h.returnType];
        [s appendFormat:@"%%hook %@\n", h.className];
        if ([h.returnType isEqualToString:@"BOOL"]) {
            [s appendFormat:@"-(BOOL)%@ { return %@; }\n", h.methodName, [h.returnValue boolValue] ? @"YES" : @"NO"];
        } else if ([h.returnType isEqualToString:@"NSInteger"] || [h.returnType isEqualToString:@"int"]) {
            [s appendFormat:@"-(NSInteger)%@ { return %ld; }\n", h.methodName, (long)[h.returnValue integerValue]];
        } else if ([h.returnType isEqualToString:@"void"]) {
            [s appendFormat:@"-(void)%@ { /* nop */ }\n", h.methodName];
        } else if ([h.returnType isEqualToString:@"id"]) {
            if (h.returnValue == nil) {
                [s appendFormat:@"-(id)%@ { return nil; }\n", h.methodName];
            } else if ([h.returnValue isKindOfClass:[NSString class]]) {
                [s appendFormat:@"-(id)%@ { return @\"%@\"; }\n", h.methodName, h.returnValue];
            } else {
                [s appendFormat:@"-(id)%@ { return nil; /* custom: %@ */ }\n", h.methodName, h.returnValue];
            }
        } else {
            [s appendFormat:@"// TODO: %@ %@\n", h.returnType, h.methodName];
        }
        [s appendString:@"%end\n\n"];
    }

    [s appendString:@"// --- Pure ObjC Runtime ---\n"];
    for (ActiveHook *h in hooks) {
        [s appendFormat:@"// [MethodHacker hookMethodWithClass:@\"%@\" methodName:@\"%@\" isClassMethod:%@ returnType:@\"%@\" value:%@];\n",
         h.className, h.methodName,
         h.isClassMethod ? @"YES" : @"NO",
         h.returnType,
         h.returnValue ? [NSString stringWithFormat:@"@(%@)", h.returnValue] : @"nil"];
    }
    return s;
}

@end
