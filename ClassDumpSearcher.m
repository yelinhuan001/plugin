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

    IMP newImp = imp_implementationWithBlock(^(id _self) { return value; });
    method_setImplementation(method, newImp);
    
    ActiveHook *h = [ActiveHook hookWithClass:className method:methodName isClass:isClassMethod returnType:returnType value:value];
    [_hooks addObject:h];
    return YES;
}
@end
