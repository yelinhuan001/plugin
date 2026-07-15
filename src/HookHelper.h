//
// HookHelper.h — ObjC Runtime 方法交换工具
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

/// 交换实例方法实现；成功返回 YES，并将原 IMP 写入 outOriginal
BOOL TDP_SwizzleInstanceMethod(Class cls, SEL sel, IMP newImp, IMP _Nullable * _Nullable outOriginal);

/// 交换类方法实现
BOOL TDP_SwizzleClassMethod(Class cls, SEL sel, IMP newImp, IMP _Nullable * _Nullable outOriginal);

/// 给已有类添加/替换方法
BOOL TDP_AddOrReplaceMethod(Class cls, SEL sel, IMP imp, const char *types, BOOL isClassMethod);

/// 安全调用原方法（需自己转型）
static inline IMP TDP_GetMethodIMP(Class cls, SEL sel, BOOL isClassMethod) {
    Method m = isClassMethod ? class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel);
    return m ? method_getImplementation(m) : NULL;
}

NS_ASSUME_NONNULL_END
