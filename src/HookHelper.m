//
// HookHelper.m
//

#import "HookHelper.h"

BOOL TDP_SwizzleInstanceMethod(Class cls, SEL sel, IMP newImp, IMP *outOriginal) {
    if (!cls || !sel || !newImp) return NO;

    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return NO;

    const char *types = method_getTypeEncoding(method);
    IMP original = method_getImplementation(method);

    // 若方法在父类，先添加再替换，避免影响父类
    if (class_addMethod(cls, sel, newImp, types)) {
        // 新加的是我们的 hook；原实现仍在父类，通过 method_getImplementation 拿不到我们要的链
        // 此时 original 仍是父类实现，可以调用
        if (outOriginal) *outOriginal = original;
        // 再把我们加的换成… 实际上 class_addMethod 已装上 newImp
        // 需要把 original 留给调用方
        return YES;
    }

    if (outOriginal) *outOriginal = method_setImplementation(method, newImp);
    else method_setImplementation(method, newImp);
    return YES;
}

BOOL TDP_SwizzleClassMethod(Class cls, SEL sel, IMP newImp, IMP *outOriginal) {
    if (!cls || !sel || !newImp) return NO;
    Class meta = object_getClass((id)cls);
    return TDP_SwizzleInstanceMethod(meta, sel, newImp, outOriginal);
}

BOOL TDP_AddOrReplaceMethod(Class cls, SEL sel, IMP imp, const char *types, BOOL isClassMethod) {
    if (!cls || !sel || !imp || !types) return NO;
    Class target = isClassMethod ? object_getClass((id)cls) : cls;
    Method m = class_getInstanceMethod(target, sel);
    if (m) {
        method_setImplementation(m, imp);
        return YES;
    }
    return class_addMethod(target, sel, imp, types);
}
