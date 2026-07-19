#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface ActiveHook : NSObject
@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *methodName;
@property (nonatomic, assign) BOOL isClassMethod;
@property (nonatomic, copy) NSString *returnType;
@property (nonatomic, strong) id returnValue;
@property (nonatomic, assign) IMP originalIMP;

+ (instancetype)hookWithClass:(NSString *)cls
                       method:(NSString *)sel
                      isClass:(BOOL)cm
                   returnType:(NSString *)type
                        value:(id)val;
@end

@interface MethodHacker : NSObject

/// Hook 指定类的方法，使其返回固定值
+ (BOOL)hookMethodWithClass:(NSString *)className
                 methodName:(NSString *)methodName
              isClassMethod:(BOOL)isClassMethod
                 returnType:(NSString *)returnType
                      value:(id)value;

/// 取消单个 Hook，恢复原始实现
+ (BOOL)unhook:(ActiveHook *)hook;

/// 取消所有活跃 Hook
+ (void)unhookAll;

/// 获取所有活跃 Hook 列表
+ (NSArray<ActiveHook *> *)activeHooks;

@end
