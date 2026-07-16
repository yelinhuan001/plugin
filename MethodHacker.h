#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

/// 存储一个活跃的 Hook 记录
@interface ActiveHook : NSObject
@property (nonatomic, strong) NSString *className;
@property (nonatomic, strong) NSString *methodName;
@property (nonatomic, assign) BOOL isClassMethod;
@property (nonatomic, strong) NSString *returnType;
@property (nonatomic, strong) id returnValue;
@property (nonatomic, assign) IMP originalIMP;
+ (instancetype)hookWithClass:(NSString *)cls method:(NSString *)sel isClass:(BOOL)classMeth returnType:(NSString *)type value:(id)value;
- (NSString *)displayDescription;
@end

/// 方法 Hook 管理器
@interface MethodHacker : NSObject

/// 所有活跃的 Hook
@property (class, readonly) NSArray<ActiveHook *> *activeHooks;

/// Hook 一个方法，强制返回固定值
+ (BOOL)hookMethodWithClass:(NSString *)className
                 methodName:(NSString *)methodName
              isClassMethod:(BOOL)isClassMethod
                 returnType:(NSString *)returnType
                      value:(id)value;

/// 取消指定 Hook
+ (BOOL)unhook:(ActiveHook *)hook;

/// 取消全部 Hook
+ (void)unhookAll;

/// 列出所有已注册类
+ (NSArray<NSString *> *)allClassesFiltered:(NSString * _Nullable)filter;

@end

NS_ASSUME_NONNULL_END
